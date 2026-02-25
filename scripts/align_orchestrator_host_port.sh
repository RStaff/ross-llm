#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Find compose file
COMPOSE_FILE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$f" ]; then COMPOSE_FILE="$f"; break; fi
done
if [ -z "$COMPOSE_FILE" ]; then
  echo "❌ Could not find compose file."
  exit 1
fi

# Detect orchestrator uvicorn port from:
# 1) docker-compose.yml (command:)
# 2) apps/orchestrator/Dockerfile (CMD ...)
DETECTED_PORT="$(python3 - <<PY
from pathlib import Path
import re, sys

compose = Path("$COMPOSE_FILE").read_text()

# Try to find port in orchestrator service command
# Handles forms like: command: uvicorn main:app --host 0.0.0.0 --port 8001
# Or: command: ["uvicorn","main:app","--port","8001"]
m_service = re.search(r"(?ms)^\s*orchestrator:\s*\n(.*?)(^\S|\Z)", compose)
block = m_service.group(1) if m_service else ""

port = None

# YAML-ish string command
m = re.search(r"(?m)^\s*command:\s*(.+)$", block)
if m:
    cmd_line = m.group(1).strip()
    # inline list
    if cmd_line.startswith("["):
        # try to find --port, <num> or --port=<num>
        m2 = re.search(r"--port(?:=|\",\s*\"|\s+)(\d+)", cmd_line)
        if m2: port = m2.group(1)
    else:
        m2 = re.search(r"--port(?:=|\s+)(\d+)", cmd_line)
        if m2: port = m2.group(1)

# If still not found, read Dockerfile CMD
if port is None:
    df = Path("apps/orchestrator/Dockerfile")
    if df.exists():
        txt = df.read_text()
        # CMD ["uvicorn","main:app","--port","8001", ...]
        m3 = re.search(r'CMD\s*\[(.*?)\]', txt, re.S)
        if m3:
            arr = m3.group(1)
            m4 = re.search(r'--port"\s*,\s*"(\d+)"', arr)
            if not m4:
                m4 = re.search(r'--port\s*",\s*"(\d+)"', arr)
            if m4: port = m4.group(1)
        if port is None:
            # CMD uvicorn main:app --port 8001
            m5 = re.search(r'CMD\s+.*--port(?:=|\s+)(\d+)', txt)
            if m5: port = m5.group(1)

print(port or "8000")
PY
)"

echo "🔎 Detected orchestrator uvicorn port inside container: ${DETECTED_PORT}"

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

# Remove any existing ports definitions (multiline or inline) inside orchestrator
out = []
i = 0
while i < len(block):
    l = block[i]
    # inline ports: [...]
    if re.match(rf"^{re.escape(child_indent)}ports:\s*\[.*\]\s*$", l):
        i += 1
        continue
    # multiline ports:
    if re.match(rf"^{re.escape(child_indent)}ports:\s*$", l):
        i += 1
        # skip list items under ports
        while i < len(block):
            nxt = block[i]
            # stop if new peer key (same indent as child keys) and not a list item
            if re.match(rf"^{re.escape(child_indent)}\S", nxt) and not nxt.lstrip().startswith("-"):
                break
            i += 1
        continue
    out.append(l)
    i += 1

# Insert a clean ports block right after orchestrator:
new_ports = [block[0], f"{child_indent}ports:", f'{child_indent}  - "8001:{int("")}"'] + out[1:]

new_lines = lines[:orch_i] + new_ports + lines[end:]
path.write_text("\n".join(new_lines) + "\n")
print(f"✅ Updated {path} orchestrator port mapping to 8001:{int('')}")
PY
