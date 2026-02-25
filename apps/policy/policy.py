import os, httpx
from fastapi import FastAPI
from pydantic import BaseModel

ORCH = os.getenv('ORCH', 'http://orchestrator:8001')
app = FastAPI()

class ChatReq(BaseModel):
    user_id: str
    text: str

@app.get("/health")
def health():
    return {"ok": True, "policy": "on"}

@app.post("/chat")
def chat(m: ChatReq):
    t = m.text.lower()
    if "password" in t:
        return {"reply": "I can’t help with that."}
    r = httpx.post(f"{ORCH}/chat", json=m.model_dump(), timeout=10)
    r.raise_for_status()
    return r.json()
