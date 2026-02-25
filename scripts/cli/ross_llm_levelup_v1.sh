#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$HOME/projects/ross-llm"
cd "$PROJECT_ROOT"

echo "🔧 Ross-LLM Level-Up v1 – profiles + LLM-ready orchestrator"
echo "📍 Project root: $PROJECT_ROOT"
echo

ORCH_MAIN="apps/orchestrator/main.py"
GATE_MAIN="apps/gateway/main.py"
ORCH_REQ="apps/orchestrator/requirements.txt"
GATE_REQ="apps/gateway/requirements.txt"
PROFILE_DIR="apps/orchestrator/profiles"

timestamp() {
  date +"%Y%m%d_%H%M%S"
}

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    local bak="${f}.bak_$(timestamp)"
    cp "$f" "$bak"
    echo "🛟 Backed up $f -> $bak"
  else
    echo "ℹ️  No existing $f to back up (skipping)."
  fi
}

ensure_req() {
  local file="$1"
  local pkg="$2"
  if [ ! -f "$file" ]; then
    echo "📄 Creating requirements file: $file"
    touch "$file"
  fi
  if ! grep -qi "^${pkg}\b" "$file"; then
    echo "➕ Adding ${pkg} to $file"
    printf '%s\n' "$pkg" >> "$file"
  else
    echo "✅ $pkg already present in $file"
  fi
}

echo "🛟 Backing up gateway and orchestrator main.py..."
backup_file "$ORCH_MAIN"
backup_file "$GATE_MAIN"
echo

echo "📁 Ensuring profile directory exists: $PROFILE_DIR"
mkdir -p "$PROFILE_DIR"
echo

echo "🧠 Writing default profile: $PROFILE_DIR/general.yaml"
cat <<'EOF_PROFILE' > "$PROFILE_DIR/general.yaml"
name: "general"
description: >
  Default Ross-LLM assistant – helps Ross juggle Abando, Ross-LLM,
  and legal/financial strategy with a bias toward automation and scripting.

system_prompt: |
  You are Ross-LLM, a personal orchestration layer for Ross Stafford.

  Core principles:
  - Be concise but concrete.
  - Prefer automation, scripts, and source-of-truth changes over manual tweaks.
  - Default to helping Ross balance Abando, Ross-LLM, and his legal/financial strategy.
  - Assume his code lives under ~/projects/<project_name> unless stated otherwise.

  You can be asked about:
  - DevOps and CI/CD for his projects (Abando, Cart-Agent, Ross-LLM, etc.).
  - AI product strategy, marketing, and interview prep.
  - Day planning and prioritization.
  - System design and automation to expand Ross's bandwidth.

  If something touches external APIs or secrets, clearly specify:
  - which env vars are needed,
  - any one-time setup steps, and
  - how to test the result safely.

  Never fabricate file paths or commands; base them on the patterns you know Ross uses.
EOF_PROFILE
echo

echo "📦 Ensuring orchestrator requirements..."
ensure_req "$ORCH_REQ" "fastapi"
ensure_req "$ORCH_REQ" "uvicorn[standard]"
ensure_req "$ORCH_REQ" "pydantic"
ensure_req "$ORCH_REQ" "pyyaml"
ensure_req "$ORCH_REQ" "httpx"
echo

echo "📦 Ensuring gateway requirements..."
ensure_req "$GATE_REQ" "fastapi"
ensure_req "$GATE_REQ" "uvicorn[standard]"
ensure_req "$GATE_REQ" "pydantic"
ensure_req "$GATE_REQ" "httpx"
echo

echo "🧠 Updating orchestrator main.py with profile-aware LLM logic (safe fallback)..."
cat <<'EOF_ORCH' > "$ORCH_MAIN"
import os
import json
from pathlib import Path
from functools import lru_cache

import yaml
import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# ---------- Config ----------

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4.1-mini")

PROFILE_DIR = Path(__file__).parent / "profiles"

# ---------- Models ----------

class ChatRequest(BaseModel):
    user_id: str
    text: str
    profile: str | None = "general"

class ChatResponse(BaseModel):
    reply: str
    profile: str

# ---------- Profiles ----------

@lru_cache(maxsize=32)
def load_profiles() -> dict[str, dict]:
    profiles: dict[str, dict] = {}
    if not PROFILE_DIR.exists():
        return profiles

    for p in PROFILE_DIR.glob("*.yaml"):
        try:
            with p.open("r") as f:
                data = yaml.safe_load(f) or {}
        except Exception:
            continue
        name = data.get("name") or p.stem
        profiles[name] = data
    return profiles

def get_profile(name: str | None) -> dict:
    profiles = load_profiles()
    if name and name in profiles:
        return profiles[name]
    if "general" in profiles:
        return profiles["general"]
    if profiles:
        # return first defined profile
        return next(iter(profiles.values()))
    # super-safe fallback
    return {
        "name": "fallback",
        "system_prompt": "You are a helpful assistant for Ross.",
    }

# ---------- LLM Client ----------

def call_openai_chat(system_prompt: str, user_text: str) -> str:
    """
    If OPENAI_API_KEY is set, call OpenAI's chat API.
    If not, stay in DEV-ECHO mode so the stack still works.
    """
    if not OPENAI_API_KEY:
        # Safe dev fallback: keep your old behavior instead of crashing
        return f"[DEV ECHO – no OPENAI_API_KEY set]\n\n{user_text}"

    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": OPENAI_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_text},
        ],
        "temperature": 0.3,
    }

    with httpx.Client(timeout=30) as client:
        r = client.post(
            "https://api.openai.com/v1/chat/completions",
            headers=headers,
            json=payload,
        )
        r.raise_for_status()
        data = r.json()

    try:
        return data["choices"][0]["message"]["content"]
    except Exception as e:
        raise RuntimeError(
            f"Bad OpenAI response shape: {e}; "
            f"raw={json.dumps(data, indent=2)[:800]}"
        )

# ---------- App ----------

app = FastAPI(title="Ross-LLM Orchestrator", version="1.0.0")

@app.get("/health")
def health():
    return {"ok": True}

@app.get("/profiles")
def list_profiles():
    profiles = load_profiles()
    return {
        "profiles": [
            {
                "name": v.get("name") or k,
                "description": v.get("description", ""),
            }
            for k, v in profiles.items()
        ]
    }

@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    profile = get_profile(req.profile)
    system_prompt = profile.get("system_prompt", "You are a helpful assistant for Ross.")
    profile_name = profile.get("name", req.profile or "unknown")

    # Later we can inject retrieval / tools here:
    #   context = retrieve_context(req.user_id, req.text)
    #   user_prompt = f"Context:\\n{context}\\n\\nUser:\\n{req.text}"
    # For now we just pass the user text directly.
    user_prompt = req.text

    try:
        reply = call_openai_chat(system_prompt, user_prompt)
    except Exception as e:
        # Gateway expects a 500 if orchestrator LLM call fails
        raise HTTPException(status_code=500, detail=f"Orchestrator LLM error: {e}")

    return ChatResponse(reply=reply, profile=profile_name)
EOF_ORCH
echo "✅ Orchestrator upgraded."
echo

echo "🌉 Updating gateway main.py to pass 'profile' through..."
cat <<'EOF_GATE' > "$GATE_MAIN"
import os

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

ORCH_URL = os.getenv("ORCH_URL", "http://orchestrator:8000")

app = FastAPI(title="Ross-LLM Gateway", version="1.0.0")

class ChatIn(BaseModel):
    user_id: str
    text: str
    profile: str | None = "general"

class ChatOut(BaseModel):
    reply: str
    profile: str | None = None

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
EOF_GATE
echo "✅ Gateway upgraded."
echo

if [ -x "./ross_llm_dev_cycle.sh" ]; then
  echo "♻️  Running full dev cycle (down → up → test)..."
  ./ross_llm_dev_cycle.sh
else
  echo "⚠️  ross_llm_dev_cycle.sh not found or not executable."
  echo "   You can rebuild manually with:"
  echo "     cd \"$PROJECT_ROOT\""
  echo "     docker compose down"
  echo "     docker compose up --build"
fi

echo
echo "🎉 Ross-LLM Level-Up v1 complete."

echo "Next steps:"
echo "  1) (Optional) Set your OpenAI key in your shell before starting the stack, e.g.:"
echo "       export OPENAI_API_KEY='sk-...' "
echo "       export OPENAI_MODEL='gpt-4.1-mini'"
echo "  2) Hit the gateway directly, e.g.:"
echo "       curl -s http://localhost:8000/health"
echo "       curl -s http://localhost:8000/chat \\"
echo "         -H 'Content-Type: application/json' \\"
echo "         -d '{\"user_id\":\"ross-local\",\"text\":\"Give me a 3-task priority list across Abando and Ross-LLM.\",\"profile\":\"general\"}'"
echo
echo "If OPENAI_API_KEY is NOT set, you'll see DEV-ECHO responses instead of real LLM output."
