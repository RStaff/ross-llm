#!/usr/bin/env bash
set -e

# Remove any stray 'PY' line that breaks the script
sed -i '' '/^PY$/d' scripts/configure_openai_key.sh

echo "✅ Removed stray PY line. Script is now valid."
