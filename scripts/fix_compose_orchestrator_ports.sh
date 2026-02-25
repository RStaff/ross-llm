#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

COMPOSE_FILE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$f" ]; then COMPOSE_FILE="$f"; break; fi
done
if [ -z "$COMPOSE_FILE" ]; then
  echo "❌ Could not find compose file."
  exit 1
fi

python3 - <<PY
from pathlib import Path
import re

path = Path("$COMPOSE_FILE")
lines = path.read_text().splitlines()

# find orchestrator block
orch_i = None
for i,l in enumerate(lines):
    if re.match(r"^\s*orchestrator:\s*$", l):
        orch_i = i
        break
if orch_i is None:
    raise SystemExit("❌ No orchestrator service found")

orch_indent = re.match(r"^(\s*)orchestrator:\s*$", lines[orch_i]).group(1)
child_indent = orch_indent + "  "

end = len(lines)
for j in range(orch_i+1, len(lines)):
    if re.match(rf"^{re.escape(orch_indent)}[A-Za-z0-9_-]+:\s*$", lines[j]):
        end = j
        break

block = lines[orch_i:end]

# Remove ALL inline ports keys inside orchestrator block: ports: ["..."]
new_block = []
for l in block:
    if re.match(rf"^{re.escape(child_indent)}ports:\s*\[.*\]\s*$", l):
        continue
    new_block.append(l)
block = new_block

# Now ensure exactly ONE multiline ports block with "8001:8000"
# Remove any existing multiline ports block entirely, then re-insert clean at top of block.
out = []
i = 0
while i < len(block):
    l = block[i]
    if re.match(rf"^{re.escape(child_indent)}ports:\s*$", l):
        # skip ports: line
        i += 1
        # skip its list items (more indented)
        while i < len(block) and (block[i].startswith(child_indent + "  -") or block[i].startswith(child_indent + "    ") or block[i].strip()== ""):
            # stop if we hit a new peer key
            if re.match(rf"^{re.escape(child_indent)}\S", block[i]) and not block[i].lstrip().startswith("-"):
                break
            i += 1
        continue
    out.append(l)
    i += 1

# Insert clean ports block right after orchestrator:
clean = [block[0], f"{child_indent}ports:", f'{child_indent}  - "8001:8000"'] + out[1:]
# Also remove any accidental duplicate "ports:" lines that might still exist
final = []
seen_ports = False
for l in clean:
    if re.match(rf"^{re.escape(child_indent)}ports:\s*$", l):
        if seen_ports:
            continue
        seen_ports = True
    final.append(l)

new_lines = lines[:orch_i] + final + lines[end:]
path.write_text("\n".join(new_lines) + "\n")
print(f"✅ Fixed orchestrator ports in {path}")
PY

echo
echo "🔎 Orchestrator section now:"
python3 - <<PY
from pathlib import Path
import re
p=Path("$COMPOSE_FILE")
s=p.read_text().splitlines()
start=None
for i,l in enumerate(s):
    if re.match(r"^\s*orchestrator:\s*$", l):
        start=i; break
for l in s[start:start+25]:
    print(l)
PY
