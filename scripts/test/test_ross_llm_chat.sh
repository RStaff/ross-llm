#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="http://localhost:8000/chat"

echo "💬 Sending test message to Ross-LLM at: \$ENDPOINT"
curl -s -X POST "\$ENDPOINT" \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": "ross-local",
    "text": "Observer Mode: I am juggling Abando and Ross-LLM."
  }' | jq .
