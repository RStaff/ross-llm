#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing StaffordOS simple dashboard..."
cd "$(dirname "$0")/.."

########################################
# 1) Ensure httpx is installed
########################################
echo "🔧 Ensuring httpx is installed in venv..."
if [ -d "venv" ]; then
  source venv/bin/activate
  pip install --quiet httpx
  deactivate || true
else
  echo "⚠️  venv not found; assuming httpx is already available."
fi

########################################
# 2) Patch apps/ui/main.py to add /dashboard
########################################
python3 << 'PY'
from pathlib import Path

path = Path("apps/ui/main.py")
text = path.read_text()

# 2a) Make sure HTMLResponse is imported
if "from fastapi.responses import HTMLResponse" not in text:
    if "from fastapi import FastAPI, Request" in text:
        text = text.replace(
            "from fastapi import FastAPI, Request",
            "from fastapi import FastAPI, Request\nfrom fastapi.responses import HTMLResponse",
        )
    else:
        # Fallback: just append import at top
        text = "from fastapi.responses import HTMLResponse\n" + text

# 2b) Add /dashboard route if not already present
if '@app.get("/dashboard"' not in text:
    snippet = '''
@app.get("/dashboard", response_class=HTMLResponse)
async def staffordos_dashboard(request: Request):
    """
    Simple StaffordOS status dashboard.
    - Calls orchestrator /health on 8000
    - Renders result as HTML
    """
    import httpx, json

    try:
        async with httpx.AsyncClient() as client:
            r = await client.get("http://127.0.0.1:8000/health", timeout=2.0)
            status = r.json()
    except Exception as e:  # pragma: no cover
        status = {"ok": False, "error": str(e)}

    html = """
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>StaffordOS Status</title>
    <style>
      body {
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: #050816;
        color: #f9fafb;
        margin: 0;
        padding: 24px;
      }
      .card {
        max-width: 720px;
        margin: 0 auto;
        background: #020617;
        border-radius: 12px;
        padding: 20px 24px;
        box-shadow: 0 18px 45px rgba(15,23,42,0.9);
        border: 1px solid #1e293b;
      }
      h1 {
        margin-top: 0;
        font-size: 24px;
      }
      .status-ok {
        color: #22c55e;
        font-weight: 600;
      }
      .status-bad {
        color: #ef4444;
        font-weight: 600;
      }
      pre {
        background: #020617;
        border-radius: 8px;
        padding: 12px;
        font-size: 12px;
        overflow-x: auto;
        border: 1px solid #1e293b;
      }
      a {
        color: #38bdf8;
        text-decoration: none;
      }
      a:hover {
        text-decoration: underline;
      }
      .footer {
        margin-top: 16px;
        font-size: 12px;
        color: #9ca3af;
      }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>StaffordOS Status</h1>
      <p>Orchestrator health:
        <span class="{status_class}">{status_text}</span>
      </p>
      <h3>Raw /health JSON</h3>
      <pre>{raw_json}</pre>
      <div class="footer">
        <a href="/">⬅ Back to chat UI</a>
      </div>
    </div>
  </body>
</html>
""".format(
        status_class="status-ok" if status.get("ok") else "status-bad",
        status_text="OK" if status.get("ok") else "Problem",
        raw_json=json.dumps(status, indent=2),
    )
    return HTMLResponse(html)
'''
    text += "\n" + snippet

path.write_text(text)
print("✅ /dashboard route installed in", path)
PY

echo "✅ StaffordOS simple dashboard installed."
echo "   Visit: http://127.0.0.1:8100/dashboard"
