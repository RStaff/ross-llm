#!/usr/bin/env bash
set -euo pipefail

cd ~/projects/ross-llm

ENDPOINT="http://localhost:8000/chat"
echo "💬 Sending test message to Ross-LLM gateway at: ${ENDPOINT}"
echo

HTTP_RESP=$(curl -sS -w '\n%{http_code}' -X POST "$ENDPOINT" \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": "ross-local",
    "text": "Observer Mode: I am juggling Abando and Ross-LLM."
  }' || true)

STATUS_CODE=$(printf '%s\n' "$HTTP_RESP" | tail -n1)
BODY=$(printf '%s\n' "$HTTP_RESP" | sed '$d')

echo "📡 HTTP status: $STATUS_CODE"
echo "📦 Response body:"
printf '%s\n' "$BODY"
