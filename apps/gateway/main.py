from fastapi import FastAPI
from pydantic import BaseModel
import httpx, os

ORCH_URL = os.getenv("ORCH_URL","http://orchestrator:8001")

app = FastAPI()

class Msg(BaseModel):
    user_id: str
    text: str

@app.get("/health")
def health(): return {"ok": True}

@app.post("/chat")
def chat(m: Msg):
    r = httpx.post(f"{ORCH_URL}/chat", json=m.model_dump(), timeout=30)
    return r.json()
