#!/usr/bin/env bash
set -euo pipefail

cd ~/projects/ross-llm

echo "🛑 Stopping Ross-LLM stack..."
docker compose down

echo "✅ Stack stopped."
