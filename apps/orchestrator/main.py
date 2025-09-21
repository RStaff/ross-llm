from fastapi import FastAPI
from pydantic import BaseModel
import os

LLM_BASE_URL = os.getenv("LLM_BASE_URL", "http://localhost:8008/v1")  # remote vLLM later

app = FastAPI()

class Msg(BaseModel):
    user_id: str
    text: str

@app.get("/health")
def health(): return {"ok": True}

@app.post("/chat")
def chat(m: Msg):
    # TODO: add retrieval + tool routing; for now echo
    return {"reply": f"Plan + tools soon. You said: {m.text}"}
