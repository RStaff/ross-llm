#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

TARGET="apps/orchestrator/routes/memory.py"
if [ ! -f "$TARGET" ]; then
  echo "❌ Not found: $TARGET"
  exit 1
fi

echo "🔎 Showing context (lines 1-120) so we can see the bad indent:"
nl -ba "$TARGET" | sed -n '1,120p'

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/orchestrator/routes/memory.py")
lines = p.read_text().splitlines()

# Typical culprit: a top-level statement accidentally indented, often like:
#     memory = load_yaml_files()
# at module scope. We'll de-indent ONLY obvious module-scope offenders.

fixed = []
changed = False

for i, line in enumerate(lines, start=1):
    # If it's an indented module-scope assignment/call that should be top-level,
    # de-indent to column 0. We target the exact patterns that have caused this crash.
    if re.match(r"^\s+memory\s*=\s*load_yaml_files\(\)\s*$", line):
        fixed.append("memory = load_yaml_files()")
        changed = True
        continue

    # Also handle "memory = {}" or similar accidental indents (rare but safe)
    if re.match(r"^\s+memory\s*=\s*\{\}\s*$", line):
        fixed.append("memory = {}")
        changed = True
        continue

    fixed.append(line)

if not changed:
    # If we didn't match, do a conservative fallback:
    # remove leading tabs (IndentationError can come from a tab inside spaces)
    fixed2 = []
    for line in fixed:
        if "\t" in line:
            fixed2.append(line.replace("\t", "    "))
            changed = True
        else:
            fixed2.append(line)
    fixed = fixed2

p.write_text("\n".join(fixed) + "\n")
print(f"✅ Patched {p} | changed={changed}")
PY

echo
echo "✅ Compile check (should be silent):"
python3 -m py_compile "$TARGET"

echo
echo "🧹 Rebuild & run:"
docker compose down --remove-orphans
docker compose up -d --build

echo
echo "📌 Status:"
docker compose ps || true

echo
echo "📜 Orchestrator logs (last 120):"
docker compose logs --tail=120 orchestrator || true

echo
echo "🌐 Quick test:"
curl -sv http://localhost:8001/openapi.json 2>&1 | tail -n 40 || true
