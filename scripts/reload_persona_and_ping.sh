#!/usr/bin/env bash
set -euo pipefail

# Make sure alias 'ross' is available in a non-interactive script
if [ -f "$HOME/.zshrc" ]; then
  source "$HOME/.zshrc"
fi

echo "📥 Reloading persona memory..."
curl -s -X POST http://127.0.0.1:8000/admin/reload-memory \
  -H "Content-Type: application/json"
echo -e "\n✅ Reloaded.\n"

echo "🧠 Quick sanity check via gateway:"
ross "Who are my daughters?"
