#!/usr/bin/env bash
set -e

echo "🔧 StaffordOS: Fixing Python 3.9-incompatible type hints in apps/ ..."

TARGETS=$(grep -RIl " | None" apps/ || true)

if [[ -z "$TARGETS" ]]; then
  echo "✅ No ' | None' type hints found. Nothing to change."
  exit 0
fi

for file in $TARGETS; do
  echo "   Patching: $file"

  # Replace "Something | None" with "Optional[Something]"
  sed -i.bak -E 's/([A-Za-z0-9_]+) \| None/Optional[\1]/g' "$file"

  # Ensure Optional is imported
  if ! grep -q "from typing import Optional" "$file"; then
    sed -i.bak '1s/^/from typing import Optional\n/' "$file"
  fi
done

echo "✅ Type hint fixes complete."
