#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

TARGET="apps/orchestrator/main.py"
if [ ! -f "$TARGET" ]; then
  echo "❌ Not found: $TARGET"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/orchestrator/main.py")
txt = p.read_text().splitlines()

# Find the PERSONA_DIR assignment line
idx = None
for i, line in enumerate(txt):
    if re.match(r"^\s*PERSONA_DIR\s*=\s*Path\(", line):
        idx = i
        break

if idx is None:
    raise SystemExit("❌ Could not find PERSONA_DIR = Path(...) line in apps/orchestrator/main.py")

# Replace with a robust block:
# - primary: /app/data/persona (if you later copy/mount it)
# - fallback: /app/profiles (already present in your container)
new_block = [
    "PERSONA_DIR = Path(__file__).resolve().parent / \"data\" / \"persona\"",
    "if not PERSONA_DIR.exists():",
    "    PERSONA_DIR = Path(__file__).resolve().parent / \"profiles\"",
]

# Remove the old single assignment line, insert block
txt = txt[:idx] + new_block + txt[idx+1:]

p.write_text("\n".join(txt) + "\n")
print("✅ Patched PERSONA_DIR with fallback to /profiles")
PY

echo
echo "🔎 Confirm PERSONA_DIR block:"
python3 - <<'PY'
from pathlib import Path
import re
p=Path("apps/orchestrator/main.py")
lines=p.read_text().splitlines()
for i,l in enumerate(lines, start=1):
    if "PERSONA_DIR" in l:
        print(f"{i}:{l}")
PY
