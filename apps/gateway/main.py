from typing import Optional
import os

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

ORCH_URL = os.getenv("ORCH_URL", "http://orchestrator:8001")

app = FastAPI(title="Ross-LLM Gateway", version="1.0.0")

class ChatIn(BaseModel):
    user_id: str
    text: str
    profile: Optional[str] = "general"

class ChatOut(BaseModel):
    reply: str
    profile: Optional[str] = None

@app.get("/health")
def health():
    return {"ok": True}

@app.post("/chat", response_model=ChatOut)
def chat(m: ChatIn):
    try:
        r = httpx.post(
            f"{ORCH_URL}/chat",
            json=m.model_dump(),
            timeout=30,
        )
        r.raise_for_status()
    except httpx.HTTPError as e:
        raise HTTPException(status_code=502, detail=f"Gateway → Orchestrator error: {e}")

    try:
        data = r.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Bad JSON from orchestrator: {e}")

    # We assume orchestrator returns { "reply": "...", "profile": "..." }
    return data
