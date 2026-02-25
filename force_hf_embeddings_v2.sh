#!/usr/bin/env bash
set -euo pipefail

HF_MODEL="${HF_MODEL:-sentence-transformers/all-MiniLM-L6-v2}"
HF_DIM="${HF_DIM:-384}"

echo "==> 0) Preconditions"
test -f docker-compose.yml || { echo "❌ docker-compose.yml not found"; exit 1; }
command -v docker >/dev/null || { echo "❌ docker not found"; exit 1; }
command -v curl >/dev/null || { echo "❌ curl not found"; exit 1; }
command -v python3 >/dev/null || { echo "❌ python3 not found"; exit 1; }

echo "==> 1) Write docker-compose.hf.override.yml"
cat > docker-compose.hf.override.yml <<EOF
services:
  orchestrator:
    environment:
      EMBEDDING_PROVIDER: hf
      HF_EMBED_MODEL: ${HF_MODEL}
      EMBEDDING_DIM: "${HF_DIM}"
EOF
echo "✅ wrote docker-compose.hf.override.yml (HF_MODEL=${HF_MODEL}, DIM=${HF_DIM})"

echo "==> 2) Stop stack"
docker compose down --remove-orphans

echo "==> 3) Rebuild orchestrator (no cache) + start stack with HF override"
docker compose -f docker-compose.yml -f docker-compose.hf.override.yml build --no-cache orchestrator
docker compose -f docker-compose.yml -f docker-compose.hf.override.yml up -d

echo "==> 4) Wait for orchestrator health"
for i in $(seq 1 60); do
  if curl -sf http://localhost:8000/health >/dev/null; then
    echo "✅ orchestrator healthy"
    break
  fi
  sleep 1
  if [ "$i" -eq 60 ]; then
    echo "❌ orchestrator did not become healthy"
    docker compose -f docker-compose.yml -f docker-compose.hf.override.yml ps || true
    docker compose -f docker-compose.yml -f docker-compose.hf.override.yml logs --tail=200 orchestrator || true
    exit 1
  fi
done

echo "==> 5) Drop docs table (needed when embedding dim changes)"
docker compose exec -T db psql -U postgres -d postgres -c 'DROP TABLE IF EXISTS docs;' >/dev/null || {
  echo "⚠️ Could not drop docs table (psql credentials/db name may differ). Showing db logs:"
  docker compose logs --tail=80 db || true
}

echo "==> 6) Smoke test: ingest"
curl -sS http://localhost:8000/ingest \
  -H "content-type: application/json" \
  -d '{"docs":[{"id":"d1","content":"Abando.ai is a Shopify abandoned-cart recovery agent."},{"id":"d2","content":"Ross-LLM stores embeddings in pgvector for retrieval."}]}' \
| python3 -m json.tool

echo "==> 7) Smoke test: retrieve"
curl -sS http://localhost:8000/retrieve/vector \
  -H "content-type: application/json" \
  -d '{"query":"Shopify abandoned cart recovery", "top_k": 3}' \
| python3 -m json.tool

echo "✅ DONE — Ross-LLM now using local HuggingFace embeddings (no OpenAI quota)."
