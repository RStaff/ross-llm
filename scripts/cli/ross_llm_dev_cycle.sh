#!/usr/bin/env bash
set -euo pipefail

cd ~/projects/ross-llm

echo "♻️  Full Ross-LLM dev cycle: down → up → test"
echo

if docker compose ps | grep -q "ross-llm-gateway-1"; then
  echo "🧹 Bringing stack down first..."
  docker compose down
  echo
fi

./ross_llm_up.sh
echo
./test_chat_via_gateway.sh
