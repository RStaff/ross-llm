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
echo "📜 Orchestrator logs (last 200 lines):"
docker compose logs --tail=200 orchestrator || true

echo
echo "🌐 Host tests (localhost:8001):"
set -x
python3 - <<'PY' || true
import http.client
for path in ["/openapi.json", "/docs", "/"]:
    try:
        c = http.client.HTTPConnection("127.0.0.1", 8001, timeout=3)
        c.request("GET", path)
        r = c.getresponse()
        body = r.read(200)
        print(path, "=>", r.status, r.reason, body[:120])
    except Exception as e:
        print(path, "=> ERROR", repr(e))
PY
set +x

echo
echo "🔎 Does openapi include /retrieve ?"
python3 - <<'PY' || true
import json, urllib.request
try:
    data = urllib.request.urlopen("http://127.0.0.1:8001/openapi.json", timeout=3).read()
    spec = json.loads(data)
    paths = sorted(spec.get("paths", {}).keys())
    hits = [p for p in paths if "retrieve" in p]
    print("retrieve paths:", hits)
    print("total paths:", len(paths))
except Exception as e:
    print("openapi parse error:", repr(e))
PY

echo
echo "✅ Testing /retrieve/multi (pretty JSON):"
curl -s http://localhost:8001/retrieve/multi \
  -H 'content-type: application/json' \
  -d '{"queries":["prove path b is working","pgvector retrieval demo"],"top_k":5}' \
  | python3 -m json.tool
