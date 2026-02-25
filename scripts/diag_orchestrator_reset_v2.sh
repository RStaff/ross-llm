#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== ps ==="
docker compose ps || true
echo

echo "=== docker inspect (restart + state) ==="
CID="$(docker compose ps -q orchestrator || true)"
if [ -n "${CID:-}" ]; then
  docker inspect -f 'Name={{.Name}} RestartCount={{.RestartCount}} Status={{.State.Status}} Running={{.State.Running}} ExitCode={{.State.ExitCode}} Error={{.State.Error}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}' "$CID" || true
else
  echo "❌ No orchestrator container id"
fi
echo

echo "=== logs (last 400) ==="
docker compose logs --tail=400 orchestrator || true
echo

echo "=== inside-container: which port is listening? (8000/8001) ==="
docker compose exec -T orchestrator python - <<'PY' || true
import socket

def can_connect(host, port):
    s = socket.socket()
    s.settimeout(0.8)
    try:
        s.connect((host, port))
        return True
    except Exception as e:
        return repr(e)
    finally:
        try: s.close()
        except: pass

for p in (8000, 8001):
    print(f"127.0.0.1:{p} ->", can_connect("127.0.0.1", p))
PY
echo

echo "=== inside-container: HTTP GET / on 8000 then 8001 ==="
docker compose exec -T orchestrator python - <<'PY' || true
import http.client

def try_get(port):
    try:
        c = http.client.HTTPConnection("127.0.0.1", port, timeout=2)
        c.request("GET", "/")
        r = c.getresponse()
        body = r.read(200)
        print(f"PORT {port} STATUS:", r.status, r.reason, "BODY<=200:", body)
    except Exception as e:
        print(f"PORT {port} ERROR:", repr(e))

try_get(8000)
try_get(8001)
PY
echo

echo "=== inside-container: import main and list routes (or traceback) ==="
docker compose exec -T orchestrator python - <<'PY' || true
import traceback
try:
    import main
    app = getattr(main, "app", None)
    print("Imported main OK. app=", type(app))
    if app is None:
        raise RuntimeError("main.app is None")
    for r in app.routes:
        path = getattr(r, "path", None)
        methods = getattr(r, "methods", None)
        name = getattr(r, "name", None)
        if path:
            print("ROUTE", path, methods, name)
except Exception:
    traceback.print_exc()
PY
echo

echo "=== host test (python) ==="
python3 - <<'PY' || true
import http.client
for path in ["/", "/openapi.json", "/memory/status"]:
    try:
        c = http.client.HTTPConnection("127.0.0.1", 8001, timeout=2)
        c.request("GET", path)
        r = c.getresponse()
        body = r.read(200)
        print(path, "=>", r.status, r.reason, body)
    except Exception as e:
        print(path, "=> ERROR", repr(e))
PY
