#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "🔧 Forcing orchestrator to listen on container port 8000..."

# --- Patch Dockerfile (apps/orchestrator/Dockerfile) ---
DF="apps/orchestrator/Dockerfile"
if [ -f "$DF" ]; then
  python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/orchestrator/Dockerfile")
txt = p.read_text()

def repl_port(s: str) -> str:
    s2 = re.sub(r"(--port\s+)(\d+)", lambda m: m.group(1) + ("8000" if m.group(2) != "8000" else m.group(2)), s)
    s2 = re.sub(r"(--port=)(\d+)", lambda m: m.group(1) + ("8000" if m.group(2) != "8000" else m.group(2)), s2)
    return s2

new = repl_port(txt)
if new != txt:
    p.write_text(new)
    print("✅ Patched Dockerfile uvicorn --port to 8000")
else:
    print("ℹ️ No --port found in Dockerfile (or already 8000)")
PY
else
  echo "ℹ️ $DF not found (ok)."
fi

# --- Patch docker-compose.yml command (if it specifies --port 8001) ---
COMPOSE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  [ -f "$f" ] && COMPOSE="$f" && break
done
if [ -z "$COMPOSE" ]; then
  echo "❌ Could not find docker compose file."
  exit 1
fi

python3 - <<PY
from pathlib import Path
import re

p = Path("$COMPOSE")
lines = p.read_text().splitlines()

# Find orchestrator block best-effort (preserve formatting)
orch_i = None
for i,l in enumerate(lines):
    if re.match(r"^\s*orchestrator:\s*$", l):
        orch_i = i
        break
if orch_i is None:
    print("ℹ️ No orchestrator service found in compose (unexpected).")
    raise SystemExit(0)

# Determine block end: next top-level service or EOF
end = len(lines)
for j in range(orch_i+1, len(lines)):
    if re.match(r"^\s{0,2}[A-Za-z0-9_-]+:\s*$", lines[j]) and not re.match(r"^\s{2,}[A-Za-z0-9_-]+:\s*$", lines[j]):
        # top-level key (rough)
        if not lines[j].lstrip().startswith(("-", "#")) and not re.match(r"^\s{4,}", lines[j]):
            end = j
            break

block = lines[orch_i:end]
changed = False

def fix_port_in_line(s: str) -> str:
    s2 = re.sub(r"(--port\s+)(\d+)", lambda m: m.group(1) + ("8000" if m.group(2) != "8000" else m.group(2)), s)
    s2 = re.sub(r"(--port=)(\d+)", lambda m: m.group(1) + ("8000" if m.group(2) != "8000" else m.group(2)), s2)
    return s2

new_block = []
for l in block:
    nl = fix_port_in_line(l)
    if nl != l:
        changed = True
    new_block.append(nl)

if changed:
    lines = lines[:orch_i] + new_block + lines[end:]
    p.write_text("\n".join(lines) + "\n")
    print(f"✅ Patched compose orchestrator command --port to 8000 in {p}")
else:
    print("ℹ️ No --port override found in orchestrator compose block (or already 8000).")
PY

echo "✅ Done."
