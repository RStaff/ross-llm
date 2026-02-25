#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

COMPOSE_FILE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$f" ]; then COMPOSE_FILE="$f"; break; fi
done
if [ -z "$COMPOSE_FILE" ]; then
  echo "❌ Could not find docker compose file."
  exit 1
fi

python3 - <<PY
from pathlib import Path
import re

path = Path("$COMPOSE_FILE")
lines = path.read_text().splitlines()

# Find orchestrator block
orch_i = None
for i,l in enumerate(lines):
    if re.match(r"^\s*orchestrator:\s*$", l):
        orch_i = i
        break
if orch_i is None:
    raise SystemExit("❌ No orchestrator: service found")

# Find end of block (next top-level service or EOF)
end = len(lines)
for j in range(orch_i+1, len(lines)):
    if re.match(r"^\s{0,1}\w.*:\s*$", lines[j]) and not re.match(r"^\s{2,}\w.*:\s*$", lines[j]):
        end = j
        break

block = lines[orch_i:end]

# Determine indent
base_indent = re.match(r"^(\s*)orchestrator:\s*$", block[0]).group(1)
child = base_indent + "  "

# Remove any existing ports/command inside orchestrator block
out = []
i = 0
while i < len(block):
    l = block[i]
    if re.match(rf"^{re.escape(child)}ports:\s*$", l):
        i += 1
        while i < len(block) and re.match(rf"^{re.escape(child)}\s*-\s*", block[i]):
            i += 1
        continue
    if re.match(rf"^{re.escape(child)}command:\s*", l):
        i += 1
        continue
    out.append(l)
    i += 1

# Insert fresh ports + command right after orchestrator:
inject = [
    out[0],
    f"{child}ports:",
    f'{child}  - "8001:8000"',
    f"{child}command: uvicorn main:app --host 0.0.0.0 --port 8000 --log-level debug --access-log",
]
new_block = inject + out[1:]

new_lines = lines[:orch_i] + new_block + lines[end:]
path.write_text("\n".join(new_lines) + "\n")
print(f"✅ Updated {path} (orchestrator -> host 8001 to container 8000, debug logs enabled)")
PY

echo
echo "🔎 Orchestrator preview:"
python3 - <<PY
from pathlib import Path
import re
p=Path("$COMPOSE_FILE")
s=p.read_text().splitlines()
start=None
for i,l in enumerate(s):
    if re.match(r"^\s*orchestrator:\s*$", l):
        start=i; break
for l in s[start:start+30]:
    print(l)
PY
