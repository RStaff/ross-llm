#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="${ROSS_LLM_ENDPOINT:-http://localhost:8000/chat}"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 \"message text\" [profile]"
  echo "  Default profile: general"
  exit 1
fi

TEXT="$1"
PROFILE="${2:-general}"

echo "💬 Sending to Ross-LLM:"
echo "   endpoint: $ENDPOINT"
echo "   profile : $PROFILE"
echo

HTTP_RESP=$(curl -sS -w '\n%{http_code}' -X POST "$ENDPOINT" \
  -H 'Content-Type: application/json' \
  -d "{
    \"user_id\": \"ross-local\",
    \"text\": \"$TEXT\",
    \"profile\": \"$PROFILE\"
  }" || true)

STATUS_CODE=$(printf '%s\n' "$HTTP_RESP" | tail -n1)
BODY=$(printf '%s\n' "$HTTP_RESP" | sed '$d')

echo "📡 HTTP status: $STATUS_CODE"
echo "📦 Raw JSON:"
printf '%s\n' "$BODY"
echo

# Pretty print reply if it looks like JSON
if command -v jq >/dev/null 2>&1; then
  REPLY_TEXT=$(printf '%s\n' "$BODY" | jq -r '.reply // empty' 2>/dev/null || true)
  PROFILE_OUT=$(printf '%s\n' "$BODY" | jq -r '.profile // empty' 2>/dev/null || true)

  if [ -n "$REPLY_TEXT" ]; then
    echo "🧠 Profile: ${PROFILE_OUT:-unknown}"
    echo "─── Reply ───"
    printf '%s\n' "$REPLY_TEXT"
  fi
fi
