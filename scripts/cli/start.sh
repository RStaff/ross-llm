#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Loading env…"
./load_env.sh

echo "🐳 Starting Ross-LLM stack…"
docker compose up -d --build

echo "⏳ Waiting for health…"
sleep 2

curl -s http://localhost:8000/health && echo "✅ Gateway healthy"
curl -s http://localhost:8000/health && echo "✅ Orchestrator healthy"

echo "✨ Ross-LLM is live."
