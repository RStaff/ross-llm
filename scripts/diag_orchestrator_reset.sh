#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== compose ps ==="
docker compose ps || true
echo

echo "=== docker port mapping ==="
docker compose port orchestrator 8001 2>/dev/null || true
echo

CID="$(docker compose ps -q orchestrator || true)"
if [ -n "${CID:-}" ]; then
  echo "=== container restart count (docker inspect) ==="
  docker inspect "$CID" --format 'Name={{.Name}} RestartCount={{.RestartCount}} State={{.State.Status}} StartedAt={{.State.StartedAt}}' || true
  echo
fi

echo "=== HOST python http test (IPv4) ==="
python3 - <<'PY' || true
import http.client, socket
try:
    c = http.client.HTTPConnection("127.0.0.1", 8001, timeout=2)
    c.request("GET", "/")
    r = c.getresponse()
    body = r.read(200)
    print("STATUS:", r.status, r.reason)
    print("BODY(<=200):", body)
except Exception as e:
    print("HOST IPv4 ERROR:", repr(e))
PY
echo

echo "=== HOST python http test (IPv6 ::1) ==="
python3 - <<'PY' || true
import http.client
try:
    c = http.client.HTTPConnection("::1", 8001, timeout=2)
    c.request("GET", "/")
    r = c.getresponse()
    body = r.read(200)
    print("STATUS:", r.status, r.reason)
    print("BODY(<=200):", body)
except Exception as e:
    print("HOST IPv6 ERROR:", repr(e))
PY
echo

echo "=== CONTAINER python http test to itself (127.0.0.1:8001) ==="
docker compose exec -T orchestrator python - <<'PY' || true
import http.client
try:
    c = http.client.HTTPConnection("127.0.0.1", 8001, timeout=2)
    c.request("GET", "/")
    r = c.getresponse()
    body = r.read(200)
    print("STATUS:", r.status, r.reason)
    print("BODY(<=200):", body)
except Exception as e:
    print("CONTAINER SELF ERROR:", repr(e))
PY
echo

echo "=== CONTAINER python connectability check ==="
docker compose exec -T orchestrator python - <<'PY' || true
import socket
def can_connect(p):
    s=socket.socket()
    s.settimeout(0.8)
    try:
        s.connect(("127.0.0.1", p))
        return True
    except Exception:
        return False
    finally:
        try: s.close()
        except: pass
for p in (8000,8001,8002):
    print(f"127.0.0.1:{p} connectable:", can_connect(p))
PY
echo

echo "=== orchestrator logs (last 300 lines) ==="
docker compose logs --tail=300 orchestrator || true
