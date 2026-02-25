#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

UI_MAIN="apps/ui/main.py"

if [ ! -f "$UI_MAIN" ]; then
  echo "❌ $UI_MAIN not found. Adjust the path in install_status_ui.sh."
  exit 1
fi

# ensure httpx is available (optional but nice)
if [ -d "venv" ]; then
  echo "🔧 Ensuring httpx is installed in venv..."
  source venv/bin/activate
  pip install httpx >/dev/null 2>&1 || true
fi

if grep -q "/api/status" "$UI_MAIN"; then
  echo "✅ UI status proxy already present – skipping."
  exit 0
fi

echo "🔧 Patching $UI_MAIN to add /api/status proxy..."

python3 - "$UI_MAIN" << 'PY'
import sys, pathlib

path = pathlib.Path(sys.argv[1])
text = path.read_text()

if "import httpx" not in text:
    # add imports near top
    lines = text.splitlines()
    inserted = False
    for i, line in enumerate(lines):
        if line.startswith("from fastapi import") or line.startswith("import fastapi") or line.startswith("from fastapi.responses"):
            lines.insert(i+1, "import httpx")
            inserted = True
            break
    if not inserted:
        lines.insert(0, "import httpx")
    text = "\n".join(lines)

if "from fastapi.responses import JSONResponse" not in text:
    if "from fastapi.responses" in text:
        # extend existing import line
        lines = []
        for line in text.splitlines():
            if line.startswith("from fastapi.responses"):
                if "JSONResponse" not in line:
                    if line.strip().endswith("import"):
                        line = line + " JSONResponse"
                    else:
                        line = line.rstrip() + ", JSONResponse"
            lines.append(line)
        text = "\n".join(lines)
    else:
        text = "from fastapi.responses import JSONResponse\n" + text

snippet = """

ORCH_URL = "http://127.0.0.1:8000"

@app.get("/api/status")
async def ui_status_proxy():
    async with httpx.AsyncClient() as client:
        try:
            r = await client.get(f"{ORCH_URL}/status", timeout=2.0)
            r.raise_for_status()
            return JSONResponse(r.json())
        except Exception as e:  # pragma: no cover
            return JSONResponse({"ok": False, "error": str(e)}, status_code=200)
"""

if "/api/status" not in text:
    text = text + snippet

path.write_text(text)
print("✅ /api/status added to", path)
PY

echo "✅ UI status proxy installed."
