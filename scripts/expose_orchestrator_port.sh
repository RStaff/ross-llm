#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Find compose file
COMPOSE_FILE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$f" ]; then COMPOSE_FILE="$f"; break; fi
done

if [ -z "$COMPOSE_FILE" ]; then
  echo "❌ Could not find docker compose file (docker-compose.yml / compose.yml etc)."
  exit 1
fi

python3 - <<PY
from pathlib import Path
import re

path = Path("$COMPOSE_FILE")
lines = path.read_text().splitlines()

# Find "orchestrator:" line (under services)
orch_i = None
for i,l in enumerate(lines):
    if re.match(r"^\s*orchestrator:\s*$", l):
        orch_i = i
        break

if orch_i is None:
    raise SystemExit(f"❌ Didn't find an 'orchestrator:' service in {path}")

orch_indent = re.match(r"^(\s*)orchestrator:\s*$", lines[orch_i]).group(1)
child_indent = orch_indent + "  "

# Determine block end (next top-level service at same indent)
end = len(lines)
for j in range(orch_i+1, len(lines)):
    if re.match(rf"^{re.escape(orch_indent)}[A-Za-z0-9_-]+:\s*$", lines[j]):
        end = j
        break

block = lines[orch_i:end]
has_ports = any(re.match(rf"^{re.escape(child_indent)}ports:\s*$", l) for l in block)

if has_ports:
    # If ports exists, ensure 8001:8000 is present
    out = []
    in_ports = False
    ports_indent = None
    present = False
    for l in block:
        out.append(l)
        if re.match(rf"^{re.escape(child_indent)}ports:\s*$", l):
            in_ports = True
            ports_indent = child_indent + "  "
            continue
        if in_ports:
            # if indentation drops back to child_indent, ports block ended
            if re.match(rf"^{re.escape(child_indent)}\S", l):
                in_ports = False
            else:
                if '8001:8000' in l.replace("'", "").replace('"',""):
                    present = True

    if not present:
        # insert after "ports:" line
        new_block = []
        inserted = False
        for l in block:
            new_block.append(l)
            if re.match(rf"^{re.escape(child_indent)}ports:\s*$", l) and not inserted:
                new_block.append(f"{child_indent}  - \"8001:8000\"")
                inserted = True
        block = new_block
else:
    # Insert ports near the top of the service block (right after orchestrator:)
    insert_at = orch_i + 1
    block = (
        lines[orch_i:orch_i+1]
        + [f"{child_indent}ports:", f"{child_indent}  - \"8001:8000\""]
        + lines[orch_i+1:end]
    )

new_lines = lines[:orch_i] + block + lines[end:]
path.write_text("\n".join(new_lines) + "\n")
print(f"✅ Updated {path} to expose orchestrator on localhost:8001")
PY

echo
echo "🔎 Diff preview (orchestrator section):"
python3 - <<PY
from pathlib import Path
import re
p=Path("$COMPOSE_FILE")
s=p.read_text().splitlines()
start=None
for i,l in enumerate(s):
    if re.match(r"^\s*orchestrator:\s*$", l):
        start=i; break
if start is None:
    raise SystemExit("no orchestrator")
# print ~35 lines
for l in s[start:start+35]:
    print(l)
PY
