#!/usr/bin/env bash
set -euo pipefail

echo "▶ Bootstrapping Ross-LLM persona, memory and gateway..."

mkdir -p packages/persona packages/memory packages/telemetry packages/agents apps/gateway

# Persona card
if [ ! -f packages/persona/persona_card.yaml ]; then
  cat > packages/persona/persona_card.yaml <<'YAML'
id: ross-llm-persona-v1.1
identity:
  name: "Ross"
  roles: ["AI-driven marketer", "PMP program manager", "systems builder", "dad-first"]
  north_star: "Stable, lucrative, time-flexible life near my daughters."
  tagline: "Momentum with integrity."
YAML
  echo "  ✓ persona_card.yaml created"
else
  echo "  • persona_card.yaml already exists, skipping"
fi

# Reasoning modes
if [ ! -f packages/persona/reasoning_modes.json ]; then
  cat > packages/persona/reasoning_modes.json <<'JSON'
{
  "modes": {
    "default": {
      "strategy": [
        "Summarize in <=2 lines",
        "List tradeoffs",
        "Recommend with why",
        "End with 3-step next actions"
      ]
    },
    "observer_mode": {
      "strategy": [
        "Prefix: 'Observer Mode — Ross notes:'",
        "OBSERVE→LABEL→OPTIONS(3)→CHOOSE→COMMIT",
        "Return one 30–60 minute time block suggestion"
      ]
    }
  }
}
JSON
  echo "  ✓ reasoning_modes.json created"
fi

# Memory schema
if [ ! -f packages/memory/schema.sql ]; then
  cat > packages/memory/schema.sql <<'SQL'
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS episodic_memories (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  topic TEXT,
  text TEXT NOT NULL,
  embedding VECTOR(1536)
);
SQL
  echo "  ✓ memory schema created"
fi

# Memory service
if [ ! -f packages/memory/service.py ]; then
  cat > packages/memory/service.py <<'PY'
from typing import List, Dict
import os
import psycopg
from pgvector.psycopg import register_vector
from sentence_transformers import SentenceTransformer

EMB_MODEL = os.getenv("EMB_MODEL", "all-MiniLM-L6-v2")
_model = SentenceTransformer(EMB_MODEL)


def connect():
    conn = psycopg.connect(os.getenv("DATABASE_URL"))
    register_vector(conn)
    return conn


def embed(texts: List[str]):
    return _model.encode(texts, normalize_embeddings=True).tolist()


def upsert_memory(topic: str, text: str):
    vec = embed([text])[0]
    with connect() as c, c.cursor() as cur:
        cur.execute(
            "INSERT INTO episodic_memories(topic, text, embedding) VALUES (%s,%s,%s)",
            (topic, text, vec),
        )


def retrieve(query: str, k: int = 6) -> List[Dict]:
    qv = embed([query])[0]
    with connect() as c, c.cursor(row_factory=psycopg.rows.dict_row) as cur:
        cur.execute(
            """
            SELECT text, topic, created_at
            FROM episodic_memories
            ORDER BY embedding <-> %s
            LIMIT %s
            """,
            (qv, k),
        )
        return list(cur.fetchall())
PY
  echo "  ✓ memory service created"
fi

# Telemetry
if [ ! -f packages/telemetry/ledger.py ]; then
  mkdir -p packages/telemetry
  cat > packages/telemetry/ledger.py <<'PY'
import time, os, json, pathlib

LOG_PATH = pathlib.Path(os.getenv("ROSSLLM_LOG", "telemetry/events.log"))

def log_event(event: dict):
    event = dict(event)
    event["ts"] = time.time()
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a") as f:
        f.write(json.dumps(event) + "\n")
PY
  echo "  ✓ telemetry ledger created"
fi

# LLM stub
if [ ! -f packages/agents/llm_client.py ]; then
  mkdir -p packages/agents
  cat > packages/agents/llm_client.py <<'PY'
from typing import List

def generate(system: str, user: str, context_chunks: List[str]) -> str:
    joined = "\n".join(context_chunks)
    return f"[ROSSLLM_STUB]\\nSYSTEM:\\n{system}\\n\\nCONTEXT:\\n{joined}\\n\\nUSER:\\n{user}\\n"
PY
  echo "  ✓ llm_client stub created"
fi

# Gateway
if [ ! -f apps/gateway/main.py ]; then
  mkdir -p apps/gateway
  cat > apps/gateway/main.py <<'PY'
import json
from pathlib import Path
from fastapi import FastAPI
from pydantic import BaseModel
from packages.memory.service import retrieve, upsert_memory
from packages.agents.llm_client import generate
from packages.telemetry.ledger import log_event

PERSONA = Path("packages/persona/persona_card.yaml").read_text()
MODES = json.loads(Path("packages/persona/reasoning_modes.json").read_text())

class ChatIn(BaseModel):
    message: str
    topic: str = "general"
    mode: str = "auto"

class ChatOut(BaseModel):
    reply: str
    mode: str
    memories_used: int

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/chat", response_model=ChatOut)
def chat(inp: ChatIn):
    mode = inp.mode
    if mode == "auto":
        triggers = ["observer mode", "third-person", "zoom out", "snapshot me"]
        lower = inp.message.lower()
        mode = "observer_mode" if any(t in lower for t in triggers) else "default"

    mems = retrieve(inp.message, k=6)
    mem_txt = [f"- {m['text']} (topic={m['topic']})" for m in mems]

    system = (
        f"You are Ross-LLM.\n\nPersona:\n{PERSONA}\n\n"
        f"Use reasoning mode: {mode}.\n"
        f"Mode strategy: {MODES['modes'][mode]['strategy']}.\n"
        "Tone: direct, encouraging, no purple prose.\n"
    )

    reply = generate(system=system, user=inp.message, context_chunks=mem_txt)

    upsert_memory(inp.topic, f"user:{inp.message}")
    upsert_memory(inp.topic, f"assistant:{reply[:800]}")

    log_event(
        {"event": "chat", "mode": mode, "topic": inp.topic, "memories_used": len(mems)}
    )

    return ChatOut(reply=reply, mode=mode, memories_used=len(mems))
PY
  echo "  ✓ gateway created"
fi

echo "✅ Bootstrap complete."
