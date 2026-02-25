#!/usr/bin/env bash
set -euo pipefail

# Always work from project root
cd ~/projects/ross-llm

echo "🔑 Paste your REAL OpenAI API key (sk-...), then press Enter:"
read -r OPENAI_KEY

if [[ -z "$OPENAI_KEY" ]]; then
  echo "❌ ERROR: No key entered. Aborting."
  exit 1
fi

echo "🔧 Setting OpenAI environment variables for this run…"

export OPENAI_API_KEY="$OPENAI_KEY"
export OPENAI_MODEL="gpt-4.1-mini"
export OPENAI_PROJECT="proj_fTlh3GrLbhppvEh6ZQdxA761"

echo "🌱 Environment set in this shell:"
echo "--------------------------------"
echo "OPENAI_API_KEY=\${OPENAI_API_KEY:0:12}…(hidden)"
echo "OPENAI_MODEL=$OPENAI_MODEL"
echo "OPENAI_PROJECT=$OPENAI_PROJECT"

echo "📝 Writing docker-compose.override.yml passthrough…"

cat <<'YML' > docker-compose.override.yml
services:
  gateway:
    environment:
      - ORCH_URL=http://orchestrator:8000

  orchestrator:
    environment:
      - OPENAI_API_KEY
      - OPENAI_MODEL
      - OPENAI_PROJECT
YML

echo "✅ docker-compose.override.yml updated."

echo "♻️  Restarting Ross-LLM stack with new environment…"
./ross_llm_dev_cycle.sh

echo "✅ Stack restarted."

echo "🔍 Sanity check inside orchestrator container:"
docker compose exec orchestrator env | grep OPENAI || true

echo "✅ Done. Now you can test with:"
echo "    cd ~/projects/ross-llm"
echo "    ./ross_llm_chat.sh \"Give me a 3-task priority list across Abando and Ross-LLM.\" general"
