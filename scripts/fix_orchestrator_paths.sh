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
txt = p.read_text()

# We anchor all "repo-ish" paths off the directory of this file.
# In Docker that becomes /app, so /app/data/... works if data is copied, or you can mount it.
needle = r"PERSONA_DIR\s*=\s*Path\(__file__\)\.resolve\(\)\.parents\[\d+\]\s*/\s*\"data\"\s*/\s*\"persona\""
if re.search(needle, txt):
    txt = re.sub(
        needle,
        "PERSONA_DIR = Path(__file__).resolve().parent / \"data\" / \"persona\"",
        txt
    )
    changed = True
else:
    changed = False

# Also defensively patch any other .parents[2] occurrences in this file
# to avoid future Docker path depth issues.
txt2 = re.sub(r"Path\(__file__\)\.resolve\(\)\.parents\[\s*2\s*\]", "Path(__file__).resolve().parent", txt)
if txt2 != txt:
    txt = txt2
    changed = True

p.write_text(txt)

print("✅ Patched", p)
print("   - Replaced PERSONA_DIR to use Path(__file__).parent/data/persona (Docker-safe)")
print("   - Replaced any remaining Path(__file__).resolve().parents[2] with .parent")
PY

echo
echo "🔎 Show the patched lines:"
grep -n "PERSONA_DIR" -n "$TARGET" || true
grep -n "parents\\[2\\]" -n "$TARGET" || true
