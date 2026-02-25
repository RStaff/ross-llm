#!/usr/bin/env bash
set -euo pipefail

echo "🔍 StaffordOS Full Integrity Test"
echo "-----------------------------------"

#################################
# 1. Confirm KEY FILE EXISTS
#################################
KEY_FILE="$HOME/.config/ross-llm/openai_api_key"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "❌ ERROR: Key file not found at:"
  echo "   $KEY_FILE"
  echo "   → Run: scripts/configure_openai_key.sh"
  exit 1
fi

echo "🔐 Key file exists at: $KEY_FILE"

#################################
# 2. Export and verify OPENAI_API_KEY
#################################
export OPENAI_API_KEY="$(cat "$KEY_FILE")"
echo "🔑 Key loaded into environment."

# Test OpenAI with a lightweight models endpoint:
echo "🌐 Testing OpenAI API connectivity..."
status=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  https://api.openai.com/v1/models)

if [[ "$status" != "200" ]]; then
  echo "❌ ERROR: Unable to reach OpenAI (status $status)"
  exit 1
fi
echo "✅ OpenAI is reachable."

#################################
# 3. Restart StaffordOS cleanly
#################################
echo ""
echo "♻️ Restarting StaffordOS..."
./staffordos_restart.sh

sleep 2

#################################
# 4. Ping orchestrator health endpoint
#################################
echo ""
echo "🩺 Checking orchestrator health..."
health=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health)

if [[ "$health" != "200" ]]; then
  echo "❌ Orchestrator failed health check (status $health)"
  exit 1
fi
echo "✅ Orchestrator is healthy."

#################################
# 5. Reload persona memory
#################################
echo ""
echo "📥 Reloading persona memory..."
mem_out=$(curl -s -X POST http://127.0.0.1:8000/admin/reload-memory)

echo "$mem_out" | grep -q '"ross_profile"' || {
  echo "❌ ERROR: ross_profile YAML not loaded."
  exit 1
}

echo "$mem_out" | grep -q '"kids_hq"' || {
  echo "❌ ERROR: kids_hq YAML not loaded."
  exit 1
}

echo "✅ Persona memory loaded."

#################################
# 6. Run actual LLM query
#################################
echo ""
echo "🧠 Running full end-to-end LLM test..."

reply=$(./ross.sh "Who are my daughters?")

echo "$reply" | grep -q "Grace" || {
  echo "❌ ERROR: LLM did not return expected memory output."
  exit 1
}

echo "🎉 SUCCESS! LLM responded correctly."
echo "--------------------------------------------"
echo "StaffordOS Integrity: 100% PASS"
echo "Everything is working end-to-end."
