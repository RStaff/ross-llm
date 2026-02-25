#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# Activate venv if present
if [ -d "venv" ]; then
  # shellcheck disable=SC1091
  source venv/bin/activate
fi

# Load API key from config file if not already set
if [ -z "${OPENAI_API_KEY:-}" ] && [ -f "$HOME/.config/ross-llm/openai_api_key" ]; then
  export OPENAI_API_KEY="$(cat "$HOME/.config/ross-llm/openai_api_key")"
fi

mkdir -p "$ROOT/logs"

echo "🚀 Starting StaffordOS orchestrator on 127.0.0.1:8000 ..."
cd "$ROOT/apps/orchestrator"

exec uvicorn main:app \
  --host 127.0.0.1 \
  --port 8000 \
  --reload
