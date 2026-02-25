#!/usr/bin/env bash
set -euo pipefail

COMPOSE="docker-compose.yml"
test -f "$COMPOSE" || COMPOSE="docker-compose.yaml"
test -f "$COMPOSE" || { echo "❌ No docker-compose.yml/.yaml found"; exit 1; }

echo "==> Backup"
ts="$(date +%s)"
cp -v "$COMPOSE" "$COMPOSE.bak_${ts}"

echo "==> Patch orchestrator: working_dir + uvicorn --app-dir /app + PYTHONPATH"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("docker-compose.yml")
if not p.exists():
    p = Path("docker-compose.yaml")

lines = p.read_text().splitlines()

out = []
i = 0
in_orch = False
orch_indent = ""
saw_workdir = False
saw_env = False
inserted = False

def is_service_key(line, indent):
    return line.startswith(indent) and line.strip().endswith(":") and not line.startswith(indent + " ")

while i < len(lines):
    line = lines[i]

    # Enter orchestrator service
    if line.strip() == "orchestrator:":
        in_orch = True
        orch_indent = line[:len(line) - len(line.lstrip())]
        saw_workdir = False
        saw_env = False
        out.append(line)
        i += 1
        continue

    # Leave orchestrator when next top-level service starts
    if in_orch and is_service_key(line, orch_indent) and line.strip() != "orchestrator:":
        # If we never inserted working_dir, add it right before leaving block
        if not saw_workdir:
            out.append(orch_indent + "  working_dir: /app")
        in_orch = False

    if in_orch:
        # detect working_dir
        if line.strip().startswith("working_dir:"):
            saw_workdir = True

        # If we see an environment block, mark it (we still force PYTHONPATH below if missing)
        if line.strip() == "environment:":
            saw_env = True

        # Patch command lines that call uvicorn to add --app-dir /app and use apps.orchestrator.main:app
        # Handles both list-form and string-form commands.
        if "uvicorn" in line:
            # Normalize common forms
            line2 = line
            # Replace target if it's main:app or orchestrator.main:app
            line2 = line2.replace("uvicorn main:app", "uvicorn apps.orchestrator.main:app")
            line2 = line2.replace("uvicorn orchestrator.main:app", "uvicorn apps.orchestrator.main:app")
            # If apps.orchestrator.main:app is present but no --app-dir, inject it after uvicorn
            if "uvicorn" in line2 and "--app-dir" not in line2:
                line2 = re.sub(r"\buvicorn\b", "uvicorn --app-dir /app", line2, count=1)
            line = line2

        out.append(line)

        # After the image/build line, inject working_dir + environment PYTHONPATH if not present yet.
        # We insert once after first occurrence of "image:" or "build:" inside orchestrator.
        if (line.strip().startswith("image:") or line.strip().startswith("build:")) and not inserted:
            if not saw_workdir:
                out.append(orch_indent + "  working_dir: /app")
                saw_workdir = True

            # ensure PYTHONPATH exists in environment. If there is no environment block at all,
            # add list-style environment right here.
            if not saw_env:
                out.append(orch_indent + "  environment:")
                out.append(orch_indent + "    - PYTHONPATH=/app")
                saw_env = True
            inserted = True

        i += 1
        continue

    out.append(line)
    i += 1

p.write_text("\n".join(out) + "\n")
print(f"✅ Patched {p}")
PY

echo "==> Rebuild + restart orchestrator"
docker compose up -d --build orchestrator

echo "==> Quick diagnostics (inside container):"
docker compose exec -T orchestrator sh -lc 'pwd; ls -la /app | head -n 40; echo "---"; ls -la /app/apps 2>/dev/null | head -n 40 || true; echo "---"; python -c "import sys; print(\"PYTHONPATH=\",__import__(\"os\").environ.get(\"PYTHONPATH\")); print(\"sys.path[0:5]=\",sys.path[0:5])"'

echo "==> Wait for health"
for i in {1..60}; do
  if curl -sf http://localhost:8001/health >/dev/null; then
    echo "✅ orchestrator healthy"
    curl -s http://localhost:8001/health || true
    exit 0
  fi
  sleep 1
done

echo "❌ Still not healthy. Recent logs:"
docker compose logs --tail=120 orchestrator || true
exit 1
