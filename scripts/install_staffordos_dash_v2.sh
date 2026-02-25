#!/usr/bin/env bash
set -e

FILE="apps/ui/main.py"

if [ ! -f "$FILE" ]; then
  echo "❌ $FILE not found. Are you in ~/projects/ross-llm?"
  exit 1
fi

python3 << 'PY'
from pathlib import Path
import textwrap

path = Path("apps/ui/main.py")
text = path.read_text()

# Ensure imports
if "import httpx" not in text:
    text = "import httpx\n" + text

if "from fastapi.responses import HTMLResponse" not in text:
    # put HTMLResponse import near top
    lines = text.splitlines()
    inserted = False
    for i, line in enumerate(lines):
        if line.startswith("from fastapi import"):
            lines.insert(i+1, "from fastapi.responses import HTMLResponse")
            inserted = True
            break
    if not inserted:
        lines.insert(0, "from fastapi.responses import HTMLResponse")
    text = "\n".join(lines)

# If /dash already exists, don't add again
if '@app.get("/dash")' in text:
    print("ℹ /dash route already present in apps/ui/main.py – no change.")
else:
    snippet = textwrap.dedent(
        '''
        @app.get("/dash")
        async def staffordos_dash():
            """
            Minimal StaffordOS status dashboard.
            Uses /status from orchestrator and shows JSON + simple status.
            """
            import json

            try:
                async with httpx.AsyncClient() as client:
                    r = await client.get("http://127.0.0.1:8000/status", timeout=2.0)
                    r.raise_for_status()
                    status = r.json()
            except Exception as e:  # pragma: no cover
                status = {"ok": False, "error": str(e)}

            ok = status.get("ok")
            ok_text = "✅ Healthy" if ok else "⚠️ Issue detected"

            html = """
            <!doctype html>
            <html>
              <head>
                <meta charset="utf-8" />
                <title>StaffordOS Dashboard</title>
                <style>
                  body {{
                    font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                    background: #020617;
                    color: #e5e7eb;
                    margin: 0;
                    padding: 2rem;
                  }}
                  h1 {{
                    margin-bottom: 0.25rem;
                  }}
                  .status {{
                    margin-bottom: 1rem;
                    font-weight: 600;
                  }}
                  pre {{
                    background: #020617;
                    border-radius: 8px;
                    padding: 1rem;
                    font-size: 12px;
                    overflow-x: auto;
                    border: 1px solid #111827;
                  }}
                  .ok {{
                    color: #22c55e;
                  }}
                  .bad {{
                    color: #f97316;
                  }}
                  a {{
                    color: #38bdf8;
                  }}
                </style>
              </head>
              <body>
                <h1>StaffordOS Dashboard</h1>
                <div class="status {status_class}">{ok_text}</div>
                <pre>{raw_json}</pre>
                <p><a href="/">Back to chat UI</a></p>
              </body>
            </html>
            """.format(
                status_class="ok" if ok else "bad",
                ok_text=ok_text,
                raw_json=json.dumps(status, indent=2),
            )

            return HTMLResponse(html)
        '''
    )

    # Append to end of file
    text = text.rstrip() + "\n\n" + snippet
    path.write_text(text)
    print("✅ /dash route appended to apps/ui/main.py")

PY

echo "✅ StaffordOS /dash dashboard installed."
echo "   Visit: http://127.0.0.1:8100/dash"
