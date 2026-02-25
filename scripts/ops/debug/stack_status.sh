#!/usr/bin/env bash
set -euo pipefail

cd ~/projects/ross-llm

echo "🐳 docker compose ps:"
docker compose ps
echo

echo "🌐 Checking GATEWAY health on http://localhost:8000/health"
if curl -sS -w '\nHTTP %{http_code}\n' http://localhost:8000/health ; then
  echo "✅ Gateway health call completed."
else
  echo "❌ Gateway /health request failed."
fi
echo

echo "🧠 Checking ORCHESTRATOR health on http://localhost:8000/health"
if curl -sS -w '\nHTTP %{http_code}\n' http://localhost:8000/health ; then
  echo "✅ Orchestrator health call completed."
else
  echo "❌ Orchestrator /health request failed."
fi
echo
