#!/usr/bin/env bash
set -euo pipefail

HF_MODEL="${HF_MODEL:-sentence-transformers/all-MiniLM-L6-v2}"
OVERRIDE_FILE="${OVERRIDE_FILE:-docker-compose.hf.override.yml}"
PGFILE="apps/orchestrator/routes/pgvector_store.py"
HFFILE="apps/orchestrator/embeddings_hf.py"
REQ="requirements.txt"

die() { echo "❌ $*" >&2; exit 1; }

echo "==> 0) Preconditions"
test -f docker-compose.yml || die "docker-compose.yml not found"
test -f "$PGFILE" || die "$PGFILE not found"
test -f "$REQ" || die "$REQ not found"
command -v docker >/dev/null || die "docker not found"
command -v python3 >/dev/null || die "python3 not found"
command -v curl >/dev/null || die "curl not found"

echo "==> 1) Ensure HF pinned block exists (idempotent, no risky deletes)"
# We only manage content inside our block markers.
python3 - <<PY
from pathlib import Path

req = Path("$REQ")
txt = req.read_text()

start = "# --- HF embeddings stack (managed by hf_apply_patch_and_reset_v2) ---"
end   = "# --- /HF embeddings stack ---"

block = f"""{start}
sentence-transformers==2.7.0
transformers>=4.41,<5
torch>=2.1.0
{end}
"""

if start in txt and end in txt:
    pre = txt.split(start)[0]
    post = txt.split(end)[1]
    txt = pre + block + post
else:
    if not txt.endswith("\n"):
        txt += "\n"
    txt += "\n" + block + "\n"

req.write_text(txt)
print("✅ requirements.txt updated (managed block)")
PY

echo "==> 2) Write apps/orchestrator/embeddings_hf.py with embed_texts()"
mkdir -p "$(dirname "$HFFILE")"
cp -f "$HFFILE" "$HFFILE.bak_$(date +%s)" 2>/dev/null || true

cat > "$HFFILE" <<'PY'
import os
from typing import List

_MODEL = None

def _get_model():
    global _MODEL
    if _MODEL is None:
        from sentence_transformers import SentenceTransformer
        name = os.getenv("HF_EMBED_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
        _MODEL = SentenceTransformer(name)
    return _MODEL

def embed_texts(texts: List[str]) -> List[List[float]]:
    m = _get_model()
    vecs = m.encode(texts, normalize_embeddings=True)
    return [v.tolist() for v in vecs]

def embedding_dim() -> int:
    m = _get_model()
    return int(m.get_sentence_embedding_dimension())
PY

# Hard verify function exists (prevents your ImportError)
python3 - <<PY
from pathlib import Path
t = Path("$HFFILE").read_text()
assert "def embed_texts" in t, "embed_texts() missing"
print("✅ embeddings_hf.py contains embed_texts()")
PY

echo "==> 3) Patch pgvector_store.py (backup + deterministic edit)"
cp "$PGFILE" "$PGFILE.bak_$(date +%s)"

python3 - <<PY
from pathlib import Path
import re

p = Path("$PGFILE")
txt = p.read_text()

# Ensure env vars exist near top (replace existing EMBED_MODEL/EMBED_DIM block if present)
txt = re.sub(
    r'EMBED_MODEL\s*=\s*os\.getenv\("EMBEDDING_MODEL",\s*"[^"]+"\)\nEMBED_DIM\s*=\s*int\(os\.getenv\("EMBEDDING_DIM",\s*"[^"]+"\)\)\n',
    'EMBEDDING_PROVIDER = os.getenv("EMBEDDING_PROVIDER", "openai")  # "openai" | "hf"\n'
    'EMBED_MODEL = os.getenv("EMBEDDING_MODEL", "text-embedding-3-small")\n'
    'HF_EMBED_MODEL = os.getenv("HF_EMBED_MODEL", "sentence-transformers/all-MiniLM-L6-v2")\n'
    'EMBED_DIM = int(os.getenv("EMBEDDING_DIM", "1536"))\n',
    txt
)

# Replace _embed() function with provider switch. Your file has a single _embed() now.
pattern = r'def _embed\(texts: List\[str\]\) -> List\[List\[float\]\]:.*?return vecs\n'
m = re.search(pattern, txt, flags=re.S)
if not m:
    raise SystemExit("Could not locate _embed() function to replace. Aborting patch.")

replacement = '''def _embed(texts: List[str]) -> List[List[float]]:
    if EMBEDDING_PROVIDER.lower() == "hf":
        from embeddings_hf import embed_texts, embedding_dim
        vecs = embed_texts(texts)
        dim = embedding_dim()
        if dim != EMBED_DIM:
            raise RuntimeError(f"Embedding dim mismatch: expected {EMBED_DIM}, got {dim} (HF model)")
        return vecs

    key = os.getenv("OPENAI_API_KEY", "")
    if not key:
        raise RuntimeError("OPENAI_API_KEY is not set")

    r = requests.post(
        "https://api.openai.com/v1/embeddings",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json={"model": EMBED_MODEL, "input": texts},
        timeout=60,
    )
    r.raise_for_status()
    data = r.json()
    vecs = [item["embedding"] for item in data["data"]]
    for v in vecs:
        if len(v) != EMBED_DIM:
            raise RuntimeError(f"Embedding dim mismatch: expected {EMBED_DIM}, got {len(v)}")
    return vecs
'''

txt = re.sub(pattern, replacement, txt, flags=re.S)
p.write_text(txt)
print("✅ Patched _embed() provider switch into pgvector_store.py")
PY

echo "==> 4) Build orchestrator (so HF deps exist in container) and detect HF dim"
docker compose build orchestrator

DIM="$(docker compose run --rm orchestrator python - <<PY
import os
os.environ["HF_EMBED_MODEL"] = "$HF_MODEL"
from embeddings_hf import embedding_dim
print(embedding_dim())
PY
)"
echo "   -> HF_MODEL=$HF_MODEL"
echo "   -> HF_DIM=$DIM"

echo "==> 5) Write override file: $OVERRIDE_FILE"
cat > "$OVERRIDE_FILE" <<EOF
services:
  orchestrator:
    environment:
      EMBEDDING_PROVIDER: "hf"
      HF_EMBED_MODEL: "$HF_MODEL"
      EMBEDDING_DIM: "$DIM"
EOF

echo "==> 6) Restart stack using override"
docker compose -f docker-compose.yml -f "$OVERRIDE_FILE" down --remove-orphans
docker compose -f docker-compose.yml -f "$OVERRIDE_FILE" up -d --build

echo "==> 7) Wait for DB then drop docs table BEFORE ingest"
for i in {1..60}; do
  if docker compose -f docker-compose.yml -f "$OVERRIDE_FILE" exec -T db pg_isready -U postgres >/dev/null 2>&1; then
    break
  fi
  sleep 1
  if [ "$i" -eq 60 ]; then
    echo "❌ db not ready"
    docker compose -f docker-compose.yml -f "$OVERRIDE_FILE" ps || true
    exit 1
  fi
done

docker compose -f docker-compose.yml -f "$OVERRIDE_FILE" exec -T db psql -U postgres -d postgres -c 'DROP TABLE IF EXISTS docs;' >/dev/null || true
echo "✅ Dropped docs table (will be recreated with vector(DIM))"

echo "==> 8) Wait for orchestrator health"
for i in {1..60}; do
  if curl -sf http://localhost:8001/health >/dev/null; then
    echo "✅ orchestrator healthy"
    break
  fi
  sleep 1
  if [ "$i" -eq 60 ]; then
    echo "❌ orchestrator did not become healthy"
    docker compose -f docker-compose.yml -f "$OVERRIDE_FILE" ps || true
    docker compose -f docker-compose.yml -f "$OVERRIDE_FILE" logs --tail=200 orchestrator || true
    exit 1
  fi
done

echo "==> 9) Smoke test ingest"
curl -sS http://localhost:8001/ingest \
  -H "content-type: application/json" \
  -d '{"docs":[{"id":"d1","content":"Abando.ai is a Shopify abandoned-cart recovery agent."},{"id":"d2","content":"Ross-LLM stores embeddings in pgvector for retrieval."}]}' \
| python3 -m json.tool >/dev/null
echo "✅ ingest ok"

echo "==> 10) Smoke test retrieve"
curl -sS http://localhost:8001/retrieve/vector \
  -H "content-type: application/json" \
  -d '{"query":"Shopify abandoned cart recovery", "top_k": 3}' \
| python3 -m json.tool >/dev/null
echo "✅ retrieve ok"

echo "✅ DONE — HF embeddings enabled (DIM=$DIM) and schema matches."
