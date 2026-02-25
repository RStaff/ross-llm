#!/usr/bin/env bash
set -euo pipefail
[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash: bash $0"; exit 1; }

SERVICE="ross-llm-openai-api-key"
ACCOUNT="${USER}"

echo "This will store your OpenAI key in macOS Keychain under:"
echo "  service: $SERVICE"
echo "  account: $ACCOUNT"
echo
read -s -p "Paste your OpenAI API key (input hidden): " OPENAI_API_KEY
echo
[[ -n "$OPENAI_API_KEY" ]] || { echo "❌ Empty key. Aborting."; exit 1; }

# Delete existing entry if present
security delete-generic-password -s "$SERVICE" -a "$ACCOUNT" >/dev/null 2>&1 || true

# Add new
security add-generic-password -s "$SERVICE" -a "$ACCOUNT" -w "$OPENAI_API_KEY" >/dev/null

echo "✅ Saved to Keychain."
echo
echo "To load it later in any terminal session:"
echo "  export OPENAI_API_KEY=\"\$(security find-generic-password -s '$SERVICE' -a '$ACCOUNT' -w)\""
