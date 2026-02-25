#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/projects/ross-llm"

echo "📦 Appending UI → orchestrator chat adapter to apps/ui/main.py ..."

cat << 'PYEOF' >> apps/ui/main.py

# ----- StaffordOS UI chat adapter (appended by staffordos_fix_ui_chat.sh) -----
from pydantic import BaseModel
import httpx

class UiChatRequest(BaseModel):
    message: str

@app.post("/api/chat")
async def ui_chat(req: UiChatRequest):
    """
    UI → Orchestrator bridge.

    UI sends:          { "message": "..." }
    Orchestrator needs: { "user_id": "...", "text": "..." }
    """
    payload = {
        "user_id": "ross-web-ui",
        "text": req.message,
    }
    resp = httpx.post("http://127.0.0.1:8000/chat", json=payload, timeout=60.0)
    resp.raise_for_status()
    return resp.json()
PYEOF

echo "✅ Adapter appended to apps/ui/main.py"
