#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(pwd)"
OVERRIDE="$APP_DIR/docker-compose.override.yml"

# Pick your HF embedding model here (safe default)
HF_MODEL="${HF_MODEL:-sentence-transformers/all-MiniLM-L6-v2}"

echo "==> 0) Preconditions"
test -f docker-compose.yml || { echo "❌ docker-compose.yml not found in $(pwd)"; exit 1; }
command -v docker >/dev/null || { echo "❌ docker not found"; exit 1; }

echo "==> 1) Ensure orchestrator image has HF deps (rebuild orchestrator only)"
docker compose build orchestrator

echo "==> 2) Detect embedding dimension for: $HF_MODEL"
DIM="$(docker compose run --rm orchestrator python - <<PY
from sentence_transformers import SentenceTransformer
m = SentenceTransformer("$HF_MODEL")
print(m.get_sentence_embedding_dimension())
PY
)"
echo "   -> detected DIM=$DIM"

echo "==> 3) Write docker-compose.override.yml (idempotent)"
cat > "$OVERRIDE" <<EOF
services:
  orchestrator:
    environment:
      EMBEDDING_PROVIDER: "hf"
      HF_EMBED_MODEL: "$HF_MODEL"
      EMBEDDING_DIM: "$DIM"
EOF
echo "✅ wrote $OVERRIDE"

echo "==> 4) Restart stack"
docker compose up -d --build

echo "==> 5) Wait for orchestrator health"
for i in {1..60}; do
  if curl -sf http://localhost:8000/health >/dev/null; then
    echo "✅ orchestrator healthy"
    break
  fi
  sleep 1
  if [ "$i" -eq 60 ]; then
    echo "❌ orchestrator did not become healthy"
    docker compose ps
    docker compose logs --tail=200 orchestrator || true
    exit 1
  fi
done

echo "==> 6) Reset docs table (required when vector(dim) changes)"
# Try common db credentials; adjust only if your compose differs
docker compose exec -T db psql -U postgres -d postgres -c 'DROP TABLE IF EXISTS docs;' >/dev/null
echo "✅ dropped docs table"

echo "==> 7) Smoke test: ingest"
curl -sS http://localhost:8000/ingest \
  -H "content-type: application/json" \
  -d '{"docs":[{"id":"d1","content":"Abando.ai is a Shopify abandoned-cart recovery agent."},{"id":"d2","content":"Ross-LLM stores embeddings in pgvector for retrieval."}]}' \
| python3 -m json.tool

echo "==> 8) Smoke test: retrieve"
curl -sS http://localhost:8000/retrieve/vector \
  -H "content-type: application/json" \
  -d '{"query":"Shopify abandoned cart recovery", "top_k": 3}' \
| python3 -m json.tool

echo "✅ SUCCESS: HF embeddings DIM=$DIM and schema matches."
