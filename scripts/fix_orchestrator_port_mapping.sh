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

# find "orchestrator:" at top-level
orch_i = None
for i,l in enumerate(lines):
    if re.match(r"^\s*orchestrator:\s*$", l):
        orch_i = i
        break
if orch_i is None:
    raise SystemExit("❌ Could not find 'orchestrator:' service in compose file.")

# find end of orchestrator block (next top-level service or end)
end = len(lines)
for j in range(orch_i+1, len(lines)):
    if re.match(r"^\S", lines[j]):  # new top-level key
        end = j
        break

block = lines[orch_i:end]

# remove any existing ports blocks inside orchestrator service
out = []
i = 0
while i < len(block):
    l = block[i]
    if re.match(r"^\s*ports:\s*$", l):
        indent = re.match(r"^(\s*)ports:\s*$", l).group(1)
        i += 1
        # skip list items under ports:
        while i < len(block) and re.match(rf"^{re.escape(indent)}\s*-\s*", block[i]):
            i += 1
        continue
    out.append(l)
    i += 1

# figure child indent (two spaces after "orchestrator:" typically)
child_indent = re.match(r"^(\s*)orchestrator:\s*$", out[0]).group(1) + "  "

# insert ports right after orchestrator:
new_block = [out[0], f"{child_indent}ports:", f'{child_indent}  - "8001:8001"'] + out[1:]

new_lines = lines[:orch_i] + new_block + lines[end:]
path.write_text("\n".join(new_lines) + "\n")
print(f"✅ Updated {path} orchestrator ports => 8001:8001")
PY

echo
echo "🔎 Orchestrator section (preview):"
python3 - <<'PY'
from pathlib import Path
import re
p=None
for f in ["docker-compose.yml","docker-compose.yaml","compose.yml","compose.yaml"]:
    if Path(f).exists():
        p=Path(f); break
s=p.read_text().splitlines()
start=None
for i,l in enumerate(s):
    if re.match(r"^\s*orchestrator:\s*$", l):
        start=i; break
for l in s[start:start+25]:
    print(l)
PY
