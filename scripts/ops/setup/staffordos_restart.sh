#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/projects/ross-llm"
PORT=8000

echo "♻️  StaffordOS restart helper"
echo "   Repo   : $REPO"
echo "   Port   : $PORT"
echo

cd "$REPO"

# 1) Check API key (so you know why you'd get DEV ECHO mode)
if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "⚠️  OPENAI_API_KEY is NOT set in this shell."
  echo "   StaffordOS will run in DEV ECHO mode (no real completions)."
  echo "   If you want full LLM, export your key first, e.g.:"
  echo "     export OPENAI_API_KEY=\"sk-...\""
  echo
fi

# 2) Kill anything on port 8000
echo "🔍 Looking for processes on port $PORT..."
PIDS="$(lsof -t -i :$PORT || true)"

if [[ -n "$PIDS" ]]; then
  echo "🔪 Killing processes on $PORT: $PIDS"
  echo "$PIDS" | xargs -r kill -9 || true
else
  echo "✅ No processes currently bound to port $PORT."
fi

# 3) Extra cleanup for stray uvicorn orchestrator procs
echo "🧹 Cleaning up stray uvicorn/orchestrator processes (if any)..."
pkill -f "uvicorn.*apps/orchestrator" 2>/dev/null || true

echo
echo "🚀 Rebooting StaffordOS via staffordos_boot.sh..."
echo "-----------------------------------------------"
./staffordos_boot.sh
