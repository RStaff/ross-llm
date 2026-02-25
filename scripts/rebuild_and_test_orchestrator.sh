#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "🧹 Rebuilding stack..."
docker compose down --remove-orphans
docker compose up -d --build

echo
echo "📌 Status:"
docker compose ps

echo
echo "📜 Orchestrator logs (last 120 lines):"
docker compose logs --tail=120 orchestrator || true

echo
echo "🌐 Host tests (localhost:8001):"
set -x
curl -sv http://localhost:8001/ 2>&1 | tail -n 40 || true
curl -sv http://localhost:8001/docs 2>&1 | tail -n 40 || true
curl -sv http://localhost:8001/openapi.json 2>&1 | tail -n 40 || true
set +x

echo
echo "✅ Testing /retrieve/multi (JSON pretty print):"
curl -s http://localhost:8001/retrieve/multi \
  -H 'content-type: application/json' \
  -d '{"queries":["prove path b is working","pgvector retrieval demo"],"top_k":5}' \
  | python3 -m json.tool
