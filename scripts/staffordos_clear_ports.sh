#!/usr/bin/env bash
set -euo pipefail

PORTS=("8000" "8100")

echo "🔪 Killing anything on ports 8000 and 8100..."

for PORT in "${PORTS[@]}"; do
  PIDS="$(lsof -tn -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -z "$PIDS" ]]; then
    echo "  Port $PORT: nothing listening."
  else
    echo "  Port $PORT: killing PIDs: $PIDS"
    kill $PIDS 2>/dev/null || true
  fi
done

echo "✅ Ports cleared."
