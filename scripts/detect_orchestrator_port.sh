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

compose_path = Path("$COMPOSE_FILE")
compose = compose_path.read_text()

# Extract orchestrator service block (best-effort)
m = re.search(r"(?ms)^\s*orchestrator:\s*\n(.*?)(^\S|\Z)", compose)
block = m.group(1) if m else ""

def find_port_in_text(t: str):
    # --port 8001 or --port=8001
    m = re.search(r"--port(?:=|\s+)(\d+)", t)
    return m.group(1) if m else None

port = None

# 1) Try compose command:
mcmd = re.search(r"(?m)^\s*command:\s*(.+)$", block)
if mcmd:
    port = find_port_in_text(mcmd.group(1))

# 2) Try Dockerfile CMD:
if port is None:
    df = Path("apps/orchestrator/Dockerfile")
    if df.exists():
        txt = df.read_text()
        port = find_port_in_text(txt)

print(port or "8000")
PY
