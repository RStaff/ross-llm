#!/usr/bin/env bash
set -euo pipefail

FILE="apps/ui/main.py"

if [ ! -f "$FILE" ]; then
  echo "❌ $FILE not found. Are you in ~/projects/ross-llm?"
  exit 1
fi

python3 << 'PY'
from pathlib import Path

path = Path("apps/ui/main.py")
text = path.read_text()

# If Request is already referenced in an import, do nothing
if "from fastapi import Request" in text or "Request" in text.splitlines()[0]:
    print("ℹ 'Request' already appears to be imported in apps/ui/main.py – no change made.")
else:
    # Safest: prepend a dedicated import at the top
    new_text = "from fastapi import Request\n" + text
    path.write_text(new_text)
    print("✅ Added 'from fastapi import Request' to apps/ui/main.py")
PY
