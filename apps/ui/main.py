from fastapi import Request
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import HTMLResponse, JSONResponse
from pathlib import Path
from typing import List
import httpx

app = FastAPI()

ORCH_URL = "http://127.0.0.1:8000/chat"
STATUS_URL = "http://127.0.0.1:8000/status"


@app.get("/", response_class=HTMLResponse)
def home():
    return """<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>StaffordOS UI</title>
    <style>
      body { font-family: sans-serif; margin: 32px; }
      #chat-log { border: 1px solid #aaa; padding: 10px; height: 300px; overflow-y: scroll; }
      .msg-user { color: #0a84ff; }
      .msg-assistant { color: #333; margin-bottom: 8px; }
    </style>
  </head>

  <body>
    <h1>StaffordOS Local UI</h1>

    <div id="chat-log"></div>

    <textarea id="chat-input" rows="3" style="width:100%;"></textarea>
    <button id="send-btn" onclick="sendMessage()">Send</button>

    <script>
      const log = document.getElementById("chat-log");
      const box = document.getElementById("chat-input");

      function add(role, text) {
        const div = document.createElement("div");
        div.className = role === "user" ? "msg-user" : "msg-assistant";
        div.textContent = text;
        log.appendChild(div);
        log.scrollTop = log.scrollHeight;
      }

      async function sendMessage() {
        const text = box.value.trim();
        if (!text) return;
        add("user", text);
        box.value = "";

        const res = await fetch("/api/chat", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ message: text })
        });
        const data = await res.json();
        add("assistant", data.reply || JSON.stringify(data));
      }
    </script>
  </body>
</html>
"""


@app.post("/api/chat")
async def ui_chat(payload: dict):
    text = payload.get("message", "").strip()
    if not text:
        return {"error": "empty message"}

    async with httpx.AsyncClient(timeout=60) as client:
        r = await client.post(ORCH_URL, json={
            "user_id": "ross-ui",
            "text": text,
            "profile": "general"
        })
        r.raise_for_status()
        return r.json()


@app.post("/api/upload")
async def upload(files: List[UploadFile] = File(...)):
    folder = Path(__file__).resolve().parents[2] / "data" / "uploads"
    folder.mkdir(parents=True, exist_ok=True)

    saved = []
    for f in files:
        dest = folder / f.filename
        dest.write_bytes(await f.read())
        saved.append(f.filename)

    return {"saved": saved}


@app.get("/status-dashboard", response_class=HTMLResponse)
async def status_dash():
    return """<!doctype html>
<html>
  <body style="font-family:sans-serif;">
    <h2>StaffordOS Status Dashboard</h2>
    <div id="stat">Loading…</div>
    <script>
      async function load() {
        const r = await fetch('/api/status');
        const data = await r.json();
        document.getElementById('stat').textContent =
          data.ok ? "Healthy ✓" : ("Unhealthy: " + data.error);
      }
      load();
      setInterval(load, 2000);
    </script>
  </body>
</html>"""


@app.get("/api/status")
async def proxy_status():
    async with httpx.AsyncClient() as client:
        try:
            r = await client.get(STATUS_URL)
            return r.json()
        except Exception as e:
            return {"ok": False, "error": str(e)}


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
