#!/usr/bin/env bash
set -euo pipefail

echo "==> PRECHECK: confirm expected files"
test -f docker-compose.yml || { echo "❌ docker-compose.yml not found here"; exit 1; }
test -f apps/orchestrator/routes/pgvector_store.py || { echo "❌ apps/orchestrator/routes/pgvector_store.py not found"; exit 1; }

echo "==> 1) Ensure HF deps in root requirements.txt (idempotent)"
python3 - <<'PY'
from pathlib import Path
req = Path("requirements.txt")
txt = req.read_text() if req.exists() else ""
lines = [l.rstrip() for l in txt.splitlines() if l.strip()]

def has(dep: str) -> bool:
    for l in lines:
        s = l.split("#")[0].strip()
        if s == dep:
            return True
        if dep == "torch" and s.startswith("torch"):
            return True
    return False

need = ["sentence-transformers==2.7.0", "torch"]
changed = False
for dep in need:
    if not has(dep):
        lines.append(dep)
        changed = True

if changed:
    req.write_text("\n".join(lines) + "\n")
    print("✅ Updated requirements.txt")
else:
    print("ℹ️ requirements.txt already has HF deps")
PY

echo "==> 2) Write apps/orchestrator/embeddings_hf.py"
mkdir -p apps/orchestrator
cat > apps/orchestrator/embeddings_hf.py <<'PY'
import os
from functools import lru_cache
from sentence_transformers import SentenceTransformer

DEFAULT_MODEL = os.environ.get(
    "HF_EMBEDDING_MODEL",
    "sentence-transformers/all-MiniLM-L6-v2",
)

@lru_cache(maxsize=1)
def _model() -> SentenceTransformer:
    return SentenceTransformer(DEFAULT_MODEL)

def embed_texts(texts: list[str]) -> list[list[float]]:
    m = _model()
    vecs = m.encode(texts, normalize_embeddings=True)
    return [v.tolist() for v in vecs]
PY
echo "✅ Wrote apps/orchestrator/embeddings_hf.py"

echo "==> 3) Patch apps/orchestrator/routes/pgvector_store.py (safe + backup)"
python3 - <<'PY'
from pathlib import Path
import time, re, sys

p = Path("apps/orchestrator/routes/pgvector_store.py")
txt = p.read_text()

if "/v1/embeddings" not in txt and "api.openai.com" not in txt:
    print("❌ pgvector_store.py does not appear to call OpenAI embeddings.")
    print("Run and paste output:")
    print('  rg -n --hidden --no-ignore-vcs "/v1/embeddings|api.openai.com" apps/orchestrator -S')
    sys.exit(2)

backup = p.with_suffix(p.suffix + f".bak_{int(time.time())}")
backup.write_text(txt)
print(f"✅ Backup created: {backup.name}")

# Ensure import
if "from embeddings_hf import embed_texts" not in txt:
    lines = txt.splitlines()
    insert_at = 0
    for i, line in enumerate(lines[:120]):
        if line.startswith("import ") or line.startswith("from "):
            insert_at = i + 1
    lines.insert(insert_at, "from embeddings_hf import embed_texts  # local HF embeddings")
    txt = "\n".join(lines) + "\n"

# Replace a common OpenAI embeddings request block
pattern = re.compile(
    r"""(?ms)
(^\s*url\s*=\s*["']https?://api\.openai\.com/v1/embeddings["']\s*\n.*?
^\s*r\s*=\s*requests\.post\(.*?\)\s*\n)
"""
)
m = pattern.search(txt)
if not m:
    print("❌ Found OpenAI embeddings reference, but request block shape didn’t match.")
    print('Paste this so I can generate an exact patch:')
    print('  nl -ba apps/orchestrator/routes/pgvector_store.py | sed -n "1,260p"')
    sys.exit(3)

block = m.group(1)
first_line = block.splitlines()[0]
indent = re.match(r"^(\s*)", first_line).group(1)

replacement = (
    f"{indent}# Local HF embeddings (avoids OpenAI API quota/billing)\n"
    f"{indent}vectors = embed_texts(texts)\n"
)

txt = txt.replace(block, replacement, 1)
p.write_text(txt)
print("✅ Patched pgvector_store.py to use local HF embeddings")
PY

echo "==> 4) Write docker-compose.override.yml to set HF embedding model"
cat > docker-compose.override.yml <<'YML'
services:
  orchestrator:
    environment:
      HF_EMBEDDING_MODEL: sentence-transformers/all-MiniLM-L6-v2
YML
echo "✅ Wrote docker-compose.override.yml"

echo "==> 5) Rebuild orchestrator only"
docker compose up -d --build orchestrator

echo "==> 6) Wait for /health"
until curl -sf http://localhost:8000/health >/dev/null; do sleep 0.2; done
curl -sS http://localhost:8000/health | python3 -m json.tool

echo "==> 7) Ingest test"
curl -sS http://localhost:8000/ingest \
  -H "content-type: application/json" \
  -d '{"docs":[{"id":"d1","content":"Abando.ai is a Shopify abandoned-cart recovery agent."},{"id":"d2","content":"Ross-LLM stores embeddings in pgvector for retrieval."}]}' \
| python3 -m json.tool

echo "==> 8) Retrieve test"
curl -sS http://localhost:8000/retrieve/vector \
  -H "content-type: application/json" \
  -d '{"query":"Shopify abandoned cart recovery", "top_k": 3}' \
| python3 -m json.tool

echo "✅ SUCCESS: ingest/retrieve now use local HuggingFace embeddings."
