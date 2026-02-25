#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== docker compose ps ==="
docker compose ps || true
echo

echo "=== orchestrator published ports (host side) ==="
docker compose port orchestrator 8000 2>/dev/null || true
docker compose port orchestrator 8001 2>/dev/null || true
echo

echo "=== orchestrator container process + args ==="
docker compose exec orchestrator sh -lc 'ps aux | sed -n "1,200p" | grep -E "uvicorn|python|main" | grep -v grep || true'
echo

echo "=== ports LISTENING inside orchestrator container ==="
docker compose exec orchestrator sh -lc 'python - <<PY
import socket
def can_connect(p):
    s=socket.socket()
    s.settimeout(0.5)
    try:
        s.connect(("127.0.0.1", p))
        return True
    except Exception:
        return False
    finally:
        try: s.close()
        except: pass

for p in (8000,8001,8002,8010):
    print(f"127.0.0.1:{p} connectable:", can_connect(p))
PY'
echo

echo "=== curl from INSIDE container (8000 then 8001) ==="
docker compose exec orchestrator sh -lc 'set -x; curl -sv http://127.0.0.1:8000/ 2>&1 | tail -n 25 || true; echo "----"; curl -sv http://127.0.0.1:8001/ 2>&1 | tail -n 25 || true'
echo

echo "=== curl from HOST (localhost:8001) ==="
set -x
curl -sv http://localhost:8001/ 2>&1 | tail -n 25 || true
set +x
echo

echo "=== orchestrator logs (last 250 lines) ==="
docker compose logs --tail=250 orchestrator || true
