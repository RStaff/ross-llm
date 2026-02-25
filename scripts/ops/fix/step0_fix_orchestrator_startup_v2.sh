#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.yml"
test -f "$COMPOSE_FILE" || COMPOSE_FILE="docker-compose.yaml"
test -f "$COMPOSE_FILE" || { echo "❌ No docker-compose.yml/.yaml found in $(pwd)"; exit 1; }

echo "==> Backup compose"
ts="$(date +%s)"
cp -v "$COMPOSE_FILE" "$COMPOSE_FILE.bak_${ts}"

echo "==> Patch compose (fast line-scan, no regex bombs)"
python3 - <<'PY'
from pathlib import Path

p = Path("docker-compose.yml")
if not p.exists():
    p = Path("docker-compose.yaml")

lines = p.read_text().splitlines()

# 1) Always replace common uvicorn patterns globally (safe + idempotent)
def fix_uvicorn(line: str) -> str:
    line = line.replace("uvicorn main:app", "uvicorn apps.orchestrator.main:app")
    line = line.replace("uvicorn orchestrator.main:app", "uvicorn apps.orchestrator.main:app")
    line = line.replace("uvicorn apps/orchestrator/main.py:app", "uvicorn apps.orchestrator.main:app")
    return line

lines = [fix_uvicorn(l) for l in lines]

# 2) Find orchestrator service block and ensure PYTHONPATH=/app exists
out = []
i = 0
found_orch = False

while i < len(lines):
    line = lines[i]
    out.append(line)

    if line.strip() == "orchestrator:":
        found_orch = True
        orch_indent = line[:len(line) - len(line.lstrip())]
        i += 1

        # copy orchestrator block, patching env as we go
        in_env = False
        env_indent = None
        env_style = None  # "list" or "map"
        has_py = False

        # lookahead buffer of orchestrator block lines
        block = []
        while i < len(lines):
            l = lines[i]
            # end of orchestrator block when we hit another top-level service key at same indent
            if l.startswith(orch_indent) and l.strip().endswith(":") and not l.startswith(orch_indent + " "):
                break
            block.append(l)
            i += 1

        # analyze env block
        # detect environment: line and then detect list vs map based on next non-empty line
        j = 0
        while j < len(block):
            l = block[j]
            if l.strip() == "environment:":
                in_env = True
                env_indent = l[:len(l) - len(l.lstrip())]
                # find next meaningful line
                k = j + 1
                while k < len(block) and block[k].strip() == "":
                    k += 1
                if k < len(block) and block[k].lstrip().startswith("- "):
                    env_style = "list"
                elif k < len(block) and ":" in block[k]:
                    env_style = "map"
                else:
                    env_style = "list"  # default
            if "PYTHONPATH" in l:
                has_py = True
            j += 1

        # if no environment section, add one near top of block (right after orchestrator:)
        if not any(l.strip() == "environment:" for l in block):
            # choose indent 2 spaces more than orch_indent
            base = orch_indent + "  "
            env_lines = [base + "environment:", base + "  - PYTHONPATH=/app"]
            # insert env_lines at start of block
            block = env_lines + block
            has_py = True
            env_style = "list"

        # if env exists but PYTHONPATH missing, inject immediately after environment:
        if not has_py:
            new_block = []
            injected = False
            for idx, l in enumerate(block):
                new_block.append(l)
                if l.strip() == "environment:" and not injected:
                    base = l[:len(l) - len(l.lstrip())]
                    if env_style == "map":
                        new_block.append(base + "  PYTHONPATH: /app")
                    else:
                        new_block.append(base + "  - PYTHONPATH=/app")
                    injected = True
            block = new_block

        # write patched block
        out.extend(block)
        continue  # don't i+=1 here; we've already advanced

    i += 1

if not found_orch:
    raise SystemExit("❌ Could not find 'orchestrator:' service in compose")

p.write_text("\n".join(out) + "\n")
print(f"✅ Patched {p}")
PY

echo "==> Rebuild + restart orchestrator"
docker compose up -d --build orchestrator

echo "==> Wait for orchestrator health"
for i in {1..60}; do
  if curl -sf http://localhost:8001/health >/dev/null; then
    echo "✅ orchestrator healthy"
    curl -s http://localhost:8001/health || true
    exit 0
  fi
  sleep 1
done

echo "❌ orchestrator did not become healthy"
docker compose ps || true
docker compose logs --tail=200 orchestrator || true
exit 1
