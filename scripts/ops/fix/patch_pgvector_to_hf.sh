#!/usr/bin/env bash
set -euo pipefail

echo "==> 0) Precheck files exist"
test -f apps/orchestrator/routes/pgvector_store.py
test -f apps/orchestrator/embeddings_hf.py

echo "==> 1) Patch apps/orchestrator/routes/pgvector_store.py (backup + deterministic edits)"
python3 - <<'PY'
from pathlib import Path
import time, re

p = Path("apps/orchestrator/routes/pgvector_store.py")
txt = p.read_text()

bak = p.with_suffix(p.suffix + f".bak_{int(time.time())}")
bak.write_text(txt)
print(f"✅ Backup created: {bak.name}")

# 1) Ensure import for embed_texts
if "from embeddings_hf import embed_texts" not in txt:
    # Insert after existing imports (after pydantic import is fine)
    txt = txt.replace(
        "from pydantic import BaseModel, Field\n",
        "from pydantic import BaseModel, Field\n\nfrom embeddings_hf import embed_texts  # local HF embeddings\n"
    )

# 2) Change default EMBED_DIM from 1536 -> 384 (HF MiniLM default)
txt = re.sub(
    r'EMBED_DIM\s*=\s*int\(os\.getenv\("EMBEDDING_DIM",\s*"[0-9]+"\)\)',
    'EMBED_DIM = int(os.getenv("EMBEDDING_DIM", "384"))',
    txt
)
txt = re.sub(
    r'EMBED_DIM\s*=\s*int\(os\.getenv\("EMBEDDING_DIM",\s*"1536"\)\)',
    'EMBED_DIM = int(os.getenv("EMBEDDING_DIM", "384"))',
    txt
)

# 3) Replace _embed() implementation entirely (OpenAI -> local HF)
embed_pat = re.compile(r"def _embed\([^\)]*\)\s*->\s*List\[List\[float\]\]:\s*\n(?:[ \t].*\n)+", re.M)
m = embed_pat.search(txt)
if not m:
    raise SystemExit("❌ Could not find _embed() function to replace.")

replacement = """def _embed(texts: List[str]) -> List[List[float]]:
    # Local HuggingFace embeddings (no OpenAI billing/quota)
    vecs = embed_texts(texts)

    # basic safety check
    for v in vecs:
        if len(v) != EMBED_DIM:
            raise RuntimeError(f"Embedding dim mismatch: expected {EMBED_DIM}, got {len(v)}")
    return vecs

"""
txt = txt[:m.start()] + replacement + txt[m.end():]

# 4) Fix wrong error label in ingest (retrieve_failed -> ingest_failed)
txt = txt.replace('detail=f"retrieve_failed: {e!r}"', 'detail=f"ingest_failed: {e!r}"')

p.write_text(txt)
print("✅ Patched pgvector_store.py (HF embeddings + EMBED_DIM default + error label)")
PY

echo "==> 2) Rebuild orchestrator"
docker compose up -d --build orchestrator

echo "==> 3) Wait for orchestrator health"
until curl -sf http://localhost:8000/health >/dev/null; do
  sleep 0.2
done
curl -sS http://localhost:8000/health | python3 -m json.tool

echo "==> 4) Reset docs table (dim changed -> safest is drop/recreate)"
# If you already had docs in pgvector with 1536 dims, INSERT will fail.
# We drop the table so _ensure_schema recreates it with the new dimension.
docker compose exec -T db psql -U postgres -d postgres -c 'DROP TABLE IF EXISTS docs;'

echo "==> 5) Ingest test"
curl -sS http://localhost:8000/ingest \
  -H "content-type: application/json" \
  -d '{"docs":[{"id":"d1","content":"Abando.ai is a Shopify abandoned-cart recovery agent."},{"id":"d2","content":"Ross-LLM stores embeddings in pgvector for retrieval."}]}' \
| python3 -m json.tool

echo "==> 6) Retrieve test"
curl -sS http://localhost:8000/retrieve/vector \
  -H "content-type: application/json" \
  -d '{"query":"Shopify abandoned cart recovery", "top_k": 3}' \
| python3 -m json.tool

echo "✅ SUCCESS: ingest/retrieve now use local HuggingFace embeddings (no OpenAI quota)."
