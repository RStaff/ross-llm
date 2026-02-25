#!/usr/bin/env bash
set -euo pipefail

# Find published host port for orchestrator container (maps to container port 8000)
PORT="$(docker compose ps orchestrator --format json 2>/dev/null \
  | python3 - <<'PY'
import json,sys,re
j=json.load(sys.stdin)
ports=j[0].get("Publishers",[])
# look for "0.0.0.0:XXXX->8000/tcp"
for p in ports:
  m=re.search(r":(\d+)->8000/tcp", p.get("PublishedPort","") or p.get("URL","") or "")
  if not m:
    m=re.search(r":(\d+)->8000/tcp", p.get("URL","") or "")
  if m:
    print(m.group(1)); sys.exit(0)
# fallback: try common
print("8001")
PY
)"

BASE="http://localhost:${PORT}"
echo "==> Using orchestrator at: $BASE"

echo "==> Health"
curl -sS "$BASE/health" | python3 -m json.tool

echo "==> Ingest"
curl -sS "$BASE/ingest" \
  -H "content-type: application/json" \
  -d '{"docs":[{"id":"d1","content":"Abando.ai is a Shopify abandoned cart recovery agent."},{"id":"d2","content":"Ross-LLM stores embeddings in pgvector for retrieval."}]}' \
| python3 -m json.tool

echo "==> Retrieve"
curl -sS "$BASE/retrieve/vector" \
  -H "content-type: application/json" \
  -d '{"query":"Shopify abandoned cart recovery", "top_k": 3}' \
| python3 -m json.tool

echo "✅ OK"
