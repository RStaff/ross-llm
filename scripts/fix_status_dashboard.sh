#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

UI_MAIN="apps/ui/main.py"

echo "🔧 Fixing /status-dashboard in $UI_MAIN ..."

python3 << 'PY'
import pathlib, textwrap

path = pathlib.Path("apps/ui/main.py")
text = path.read_text()

# 1) If we already have a clean, known-good route, do nothing
if '@app.get("/status-dashboard", response_class=HTMLResponse)' in text:
    print("✅ /status-dashboard route already present and looks good.")
    raise SystemExit(0)

# 2) If there's any leftover broken HTML block, trim from its marker
# We use 'StaffordOS Status' as the marker we know was in the HTML
marker = "StaffordOS Status"
if marker in text:
    before, _sep, _after = text.partition(marker)
    # Cut off at the line *before* the marker to avoid half-lines
    lines = before.splitlines()
    text = "\n".join(lines).rstrip()
    print("🧹 Removed old/broken status-dashboard HTML block.")

# 3) Ensure we have the HTMLResponse import
if "from fastapi.responses import HTMLResponse" not in text:
    if "from fastapi import FastAPI" in text:
        text = text.replace(
            "from fastapi import FastAPI",
            "from fastapi import FastAPI\nfrom fastapi.responses import HTMLResponse",
        )
        print("➕ Added HTMLResponse import after FastAPI import.")
    else:
        # Fallback: prepend import at top
        text = "from fastapi.responses import HTMLResponse\n" + text
        print("➕ Prepended HTMLResponse import at top of file.")

# 4) Append a clean, valid /status-dashboard route
snippet = '''
@app.get("/status-dashboard", response_class=HTMLResponse)
async def status_dashboard():
    return """<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>StaffordOS Status</title>
  </head>
  <body>
    <h1>StaffordOS Status</h1>
    <div id="result">Loading...</div>
    <script>
      async function refresh() {
        const r = await fetch('/api/status');
        const data = await r.json();
        const el = document.getElementById('result');
        if (!data.ok) {
          el.innerHTML = '<b style="color:red">Unhealthy</b>';
        } else {
          const uptime = Math.floor((data.uptime_seconds || 0) / 60);
          el.innerHTML = '<b style="color:#4caf50">Healthy</b> - uptime: ' + uptime + 'm';
        }
      }
      refresh();
      setInterval(refresh, 1000);
    </script>
  </body>
</html>"""
'''

text = text.rstrip() + "\n\n" + textwrap.dedent(snippet)
path.write_text(text)
print("✅ /status-dashboard route appended cleanly.")
PY

echo "🎉 fix_status_dashboard.sh completed."
