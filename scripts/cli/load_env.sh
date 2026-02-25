#!/usr/bin/env bash
set -euo pipefail

if [ ! -f ".env.secrets" ]; then
  echo "❌ .env.secrets missing! Cannot continue."
  exit 1
fi

# Load key/value pairs
source .env.secrets

if [[ "$OPENAI_API_KEY" == "REPLACE_ME" ]]; then
  echo "❌ ERROR: You must insert your real OpenAI API key in .env.secrets"
  exit 1
fi

export OPENAI_API_KEY
export OPENAI_MODEL
export OPENAI_PROJECT

echo "🔑 Environment loaded:"
echo "  OPENAI_MODEL=$OPENAI_MODEL"
echo "  OPENAI_PROJECT=$OPENAI_PROJECT"
echo "  OPENAI_API_KEY=${OPENAI_API_KEY:0:10}…(hidden)"
