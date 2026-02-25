#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Activate venv if present
if [ -d "venv" ]; then
  # shellcheck disable=SC1091
  source venv/bin/activate
fi

# Optional: warn if orchestrator is not healthy
if ! curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1; then
  echo "⚠ Orchestrator not healthy on 8000. Start it first with: ./staffordos_boot.sh"
fi

mkdir -p "$ROOT/logs"

echo "🖥  Starting StaffordOS UI on 127.0.0.1:8100 ..."
cd "$ROOT/apps/ui"

exec uvicorn main:app \
  --host 127.0.0.1 \
  --port 8100 \
  --reload
