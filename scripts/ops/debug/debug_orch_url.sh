#!/usr/bin/env bash
set -euo pipefail

cd ~/projects/ross-llm

echo "🐚 Inspecting ORCH_URL inside gateway container..."
echo

docker compose ps

echo
echo "🔎 Gateway ORCH_URL:"
docker compose exec gateway env | grep -E '^ORCH_URL=' || echo "⚠️ No ORCH_URL set in gateway container."

echo
echo "🧠 Orchestrator port-related env (if any):"
docker compose exec orchestrator env | grep -E 'PORT|ORCH' || true

echo
echo "Tip: ORCH_URL should be: ORCH_URL=http://orchestrator:8000"
