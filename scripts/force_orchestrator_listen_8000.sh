#!/usr/bin/env bash
set -euo pipefail

TARGET="apps/orchestrator/Dockerfile"

if [ ! -f "$TARGET" ]; then
  echo "❌ Not found: $TARGET"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/orchestrator/Dockerfile")
txt = p.read_text()

# Replace any uvicorn port with 8000
txt2 = re.sub(
    r'--port\s+\d+',
    '--port 8000',
    txt
)

txt2 = re.sub(
    r'--port=\d+',
    '--port=8000',
    txt2
)

p.write_text(txt2)
print("✅ Dockerfile patched → uvicorn now runs on port 8000")
PY

echo
echo "🔎 Confirm:"
grep -n "uvicorn" "$TARGET" || true
