#!/usr/bin/env bash
set -euo pipefail

cd ~/projects/ross-llm

echo "🚀 (Re)building and starting Ross-LLM stack..."
docker compose up -d --build

echo "⏳ Waiting for gateway and orchestrator health..."

GATEWAY_URL="http://localhost:8000/health"
ORCH_URL="http://localhost:8000/health"

tries=0
max_tries=20
sleep_sec=2

while true; do
  ((tries++)) || true
  echo "  🔎 Health check attempt ${tries}/${max_tries}..."

  gw_ok=false
  orch_ok=false

  if curl -s "$GATEWAY_URL" | grep -q '"ok":true'; then
    gw_ok=true
  fi

  if curl -s "$ORCH_URL" | grep -q '"ok":true'; then
    orch_ok=true
  fi

  if $gw_ok && $orch_ok; then
    echo "✅ Both gateway and orchestrator are healthy."
    break
  fi

  if [ "$tries" -ge "$max_tries" ]; then
    echo "❌ Services did not become healthy in time."
    echo "   Tip: run ./stack_status.sh to inspect."
    exit 1
  fi

  sleep "$sleep_sec"
done

echo "📊 Current stack status:"
./stack_status.sh
