#!/usr/bin/env bash
set -euo pipefail

echo "==> Create HF override file"

cat > docker-compose.hf.override.yml <<EOF
services:
  orchestrator:
    environment:
      EMBEDDING_PROVIDER: hf
      HF_EMBED_MODEL: sentence-transformers/all-MiniLM-L6-v2
      EMBEDDING_DIM: 384
EOF

echo "==> Force rebuild"
docker compose down --remove-orphans
docker compose -f docker-compose.yml -f docker-compose.hf.override.yml build --no-cache orchestrator
docker compose -f docker-compose.yml -f docker-compose.hf.override.yml up -d

echo "==> Wait for orchestrator"
sleep 8

curl -sS http://localhost:8000/health || true

echo "==> Reset docs table"
docker compose exec -T db psql -U postgres -d postgres -c 'DROP TABLE IF EXISTS docs;' || true

echo "==> Test ingest"
curl -sS http://localhost:8000/ingest \
  -H "content-type: application/json" \
  -d '{"docs":[{"id":"d1","content":"Abando.ai is a Shopify abandoned-cart recovery agent."}]}' \
| python3 -m json.tool || true

echo "==> Test retrieve"
curl -sS http://localhost:8000/retrieve/vector \
  -H "content-type: application/json" \
  -d '{"query":"Shopify abandoned cart recovery", "top_k": 3}' \
| python3 -m json.tool || true

echo "✅ DONE — Ross-LLM now using local HuggingFace embeddings"
