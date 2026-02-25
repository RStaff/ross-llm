#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
BASE_COMPOSE="$ROOT/docker-compose.yml"
HF_OVERRIDE="$ROOT/docker-compose.hf.override.yml"

# You can override this per-run:
#   HF_MODEL=sentence-transformers/all-mpnet-base-v2 ./switch_to_hf_embeddings_v2.sh
HF_MODEL="${HF_MODEL:-sentence-transformers/all-MiniLM-L6-v2}"

compose() {
  docker compose -f "$BASE_COMPOSE" -f "$HF_OVERRIDE" "$@"
}

echo "==> 0) Preconditions"
test -f "$BASE_COMPOSE" || { echo "❌ docker-compose.yml not found in $ROOT"; exit 1; }
command -v docker >/dev/null || { echo "❌ docker not found"; exit 1; }

echo "==> 1) Ensure HF deps in root requirements.txt (idempotent)"
REQ="$ROOT/requirements.txt"
test -f "$REQ" || { echo "❌ requirements.txt not found"; exit 1; }

cp -n "$REQ" "$REQ.bak_hf_$(date +%s)" || true

# remove existing lines that can conflict
grep -vE '^(sentence-transformers|transformers|torch)(==|>=|<=|<|>|~=)?' "$REQ" > "$REQ.tmp" || true
mv "$REQ.tmp" "$REQ"

cat >> "$REQ" <<'EOF'

# --- HF embeddings stack (pinned for stability) ---
sentence-transformers==2.7.0
transformers>=4.41,<5
torch>=2.1.0
EOF

echo "✅ Updated requirements.txt"

echo "==> 2) Write apps/orchestrator/embeddings_hf.py (idempotent)"
HF_PY="$ROOT/apps/orchestrator/embeddings_hf.py"
mkdir -p "$(dirname "$HF_PY")"

cat > "$HF_PY" <<'PY'
from __future__ import annotations
import os
from typing import List
from functools import lru_cache

@lru_cache(maxsize=1)
def _model():
    from sentence_transformers import SentenceTransformer
    name = os.getenv("HF_EMBED_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
    return SentenceTransformer(name)

def embed(texts: List[str]) -> List[List[float]]:
    m = _model()
    vecs = m.encode(texts, normalize_embeddings=True)  # cosine-friendly
    # vecs is numpy array
    return [v.tolist() for v in vecs]
PY

echo "✅ Wrote $HF_PY"

echo "==> 3) Patch apps/orchestrator/routes/pgvector_store.py (backup + provider switch)"
PG="$ROOT/apps/orchestrator/routes/pgvector_store.py"
test -f "$PG" || { echo "❌ $PG not found"; exit 1; }
cp -n "$PG" "$PG.bak_hf_$(date +%s)" || true

python3 - <<'PY'
from pathlib import Path
import re

pg = Path("apps/orchestrator/routes/pgvector_store.py")
txt = pg.read_text()

# Fix incorrect error label in ingest handler if present
txt = txt.replace('detail=f"retrieve_failed: {e!r}"', 'detail=f"ingest_failed: {e!r}"')

# If we already have provider switch, do nothing
if "EMBEDDING_PROVIDER" in txt and "embeddings_hf" in txt:
    pg.write_text(txt)
    print("ℹ️ pgvector_store.py already looks HF-capable; kept as-is (and fixed ingest_failed label if needed).")
    raise SystemExit(0)

# Replace the entire _embed() function body with provider-aware version
pat = r"def _embed\(texts: List\[str\]\) -> List\[List\[float\]\]:\n(?:[ \t].*\n)+?\s*return vecs\n"
m = re.search(pat, txt)
if not m:
    print("❌ Could not locate _embed() function to patch.")
    print("   Paste: nl -ba apps/orchestrator/routes/pgvector_store.py | sed -n '1,120p'")
    raise SystemExit(1)

replacement = """def _embed(texts: List[str]) -> List[List[float]]:
    provider = os.getenv("EMBEDDING_PROVIDER", "openai").lower().strip()

    if provider == "hf":
        from embeddings_hf import embed as hf_embed
        vecs = hf_embed(texts)
        # safety check when EMBEDDING_DIM is set
        expected = int(os.getenv("EMBEDDING_DIM", str(len(vecs[0]) if vecs else 0)) or 0)
        for v in vecs:
            if expected and len(v) != expected:
                raise RuntimeError(f"Embedding dim mismatch: expected {expected}, got {len(v)}")
        return vecs

    # default: OpenAI embeddings (legacy)
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
    # basic safety check
    for v in vecs:
        if len(v) != EMBED_DIM:
            raise RuntimeError(f"Embedding dim mismatch: expected {EMBED_DIM}, got {len(v)}")
    return vecs
"""

txt2 = re.sub(pat, replacement, txt)

pg.write_text(txt2)
print("✅ Patched pgvector_store.py: provider switch (hf/openai) + ingest_failed label fix.")
PY

echo "==> 4) Build orchestrator (needs HF deps)"
docker compose build orchestrator

echo "==> 5) Detect embedding dimension for: $HF_MODEL"
DIM="$(docker compose run --rm orchestrator python - <<PY
from sentence_transformers import SentenceTransformer
m = SentenceTransformer("$HF_MODEL")
print(m.get_sentence_embedding_dimension())
PY
)"
echo "   -> detected DIM=$DIM"

echo "==> 6) Write docker-compose.hf.override.yml (does NOT overwrite your existing override)"
cat > "$HF_OVERRIDE" <<EOF
services:
  orchestrator:
    environment:
      EMBEDDING_PROVIDER: "hf"
      HF_EMBED_MODEL: "$HF_MODEL"
      EMBEDDING_DIM: "$DIM"
EOF
echo "✅ wrote $HF_OVERRIDE"

echo "==> 7) Restart stack with HF override"
compose up -d --build

echo "==> 8) Wait for orchestrator health"
for i in {1..60}; do
  if curl -sf http://localhost:8000/health >/dev/null; then
    echo "✅ orchestrator healthy"
    break
  fi
  sleep 1
  if [ "$i" -eq 60 ]; then
    echo "❌ orchestrator did not become healthy"
    compose ps
    compose logs --tail=200 orchestrator || true
    exit 1
  fi
done

echo "==> 9) Drop docs table (required when vector(dim) changes) using container POSTGRES_* env"
DB_USER="$(compose exec -T db sh -lc 'echo "${POSTGRES_USER:-postgres}"')"
DB_NAME="$(compose exec -T db sh -lc 'echo "${POSTGRES_DB:-postgres}"')"
echo "   -> using DB_USER=$DB_USER DB_NAME=$DB_NAME"

compose exec -T db psql -U "$DB_USER" -d "$DB_NAME" -c 'DROP TABLE IF EXISTS docs;' >/dev/null
echo "✅ dropped docs table"

echo "==> 10) Smoke test: ingest"
curl -sS http://localhost:8000/ingest \
  -H "content-type: application/json" \
  -d '{"docs":[{"id":"d1","content":"Abando.ai is a Shopify abandoned-cart recovery agent."},{"id":"d2","content":"Ross-LLM stores embeddings in pgvector for retrieval."}]}' \
| python3 -m json.tool

echo "==> 11) Smoke test: retrieve"
curl -sS http://localhost:8000/retrieve/vector \
  -H "content-type: application/json" \
  -d '{"query":"Shopify abandoned cart recovery", "top_k": 3}' \
| python3 -m json.tool

echo "✅ SUCCESS: ingest/retrieve now use LOCAL HF embeddings (no OpenAI quota)."
echo "   Provider=hf  Model=$HF_MODEL  Dim=$DIM"
