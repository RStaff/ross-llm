#!/usr/bin/env bash
set -euo pipefail

echo "==> Checking repo"
test -f docker-compose.yml || test -f docker-compose.yaml || { echo "❌ No docker-compose.yml found in $(pwd)"; exit 1; }

COMPOSE_FILE="docker-compose.yml"
test -f "$COMPOSE_FILE" || COMPOSE_FILE="docker-compose.yaml"

echo "==> Backup compose"
ts="$(date +%s)"
cp -v "$COMPOSE_FILE" "$COMPOSE_FILE.bak_${ts}"

echo "==> Patching orchestrator command to use package import (apps.orchestrator.main:app) + PYTHONPATH"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("docker-compose.yml")
if not p.exists():
    p = Path("docker-compose.yaml")

txt = p.read_text()

# Very light-touch heuristic:
# - Ensure orchestrator service has PYTHONPATH=/app
# - Replace any uvicorn command like "uvicorn main:app" with "uvicorn apps.orchestrator.main:app"

def replace_uvicorn(s: str) -> str:
    s2 = re.sub(r'uvicorn\s+main:app', 'uvicorn apps.orchestrator.main:app', s)
    s2 = re.sub(r'uvicorn\s+orchestrator\.main:app', 'uvicorn apps.orchestrator.main:app', s2)
    return s2

new = txt

# Patch common inline command formats
new = replace_uvicorn(new)

# Ensure PYTHONPATH appears under orchestrator environment.
# If orchestrator block exists but PYTHONPATH missing, insert it.
if "orchestrator:" not in new:
    raise SystemExit("❌ Could not find 'orchestrator:' service in compose file")

# naive block extraction: insert PYTHONPATH under orchestrator's environment if environment exists
lines = new.splitlines()
out = []
in_orch = False
indent = ""
inserted = False
for i, line in enumerate(lines):
    out.append(line)
    if re.match(r'^\s*orchestrator:\s*$', line):
        in_orch = True
        indent = re.match(r'^(\s*)', line).group(1)
        continue

    if in_orch:
        # end of service block when we hit another top-level service (same indent, non-empty, ends with :)
        if re.match(rf'^{indent}\S.*:\s*$', line) and not line.strip().startswith(("image:", "build:", "command:", "environment:", "depends_on:", "ports:", "volumes:", "restart:", "healthcheck:")) and line.strip() != "orchestrator:":
            in_orch = False

        # Insert PYTHONPATH if environment block present and we see first env item
        if re.match(rf'^{indent}\s+environment:\s*$', line):
            # look ahead for env entries
            continue

# second pass: inject PYTHONPATH if environment list exists for orchestrator
# handle both list-style and map-style environment
txt2 = "\n".join(out)

# Map-style environment:
# environment:
#   FOO: bar
if re.search(r'(?ms)^\s*orchestrator:\s*\n(?:^\s+.*\n)*?^\s+environment:\s*\n(?:^\s+\S+:\s*.*\n)+', txt2):
    # if PYTHONPATH not present in orchestrator env map, insert it right after environment:
    def add_py_path_map(m):
        block = m.group(0)
        if re.search(r'^\s+PYTHONPATH:\s*', block, flags=re.M):
            return block
        return re.sub(r'(^\s+environment:\s*\n)', r'\1    PYTHONPATH: /app\n', block, flags=re.M)
    txt2 = re.sub(r'(?ms)^\s*orchestrator:\s*\n(?:^\s+.*\n)*?^\s+environment:\s*\n(?:^\s+\S+:\s*.*\n)+', add_py_path_map, txt2, count=1)

# List-style environment:
# environment:
#   - FOO=bar
if re.search(r'(?ms)^\s*orchestrator:\s*\n(?:^\s+.*\n)*?^\s+environment:\s*\n(?:^\s+-\s+\S+\n)+', txt2):
    def add_py_path_list(m):
        block = m.group(0)
        if re.search(r'^\s+-\s+PYTHONPATH=', block, flags=re.M):
            return block
        return re.sub(r'(^\s+environment:\s*\n)', r'\1    - PYTHONPATH=/app\n', block, flags=re.M)
    txt2 = re.sub(r'(?ms)^\s*orchestrator:\s*\n(?:^\s+.*\n)*?^\s+environment:\s*\n(?:^\s+-\s+\S+\n)+', add_py_path_list, txt2, count=1)

p.write_text(txt2)
print(f"✅ Patched {p}")
PY

echo "==> Rebuild + restart orchestrator"
docker compose up -d --build orchestrator

echo "==> Wait for orchestrator health"
for i in {1..60}; do
  if curl -sf http://localhost:8001/health >/dev/null; then
    echo "✅ orchestrator healthy"
    exit 0
  fi
  sleep 1
done

echo "❌ orchestrator did not become healthy"
docker compose ps || true
docker compose logs --tail=200 orchestrator || true
exit 1
