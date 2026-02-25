
from typing import Optional
import os
import json
from pathlib import Path
from functools import lru_cache

import yaml
import httpx
from fastapi import FastAPI, HTTPException
from status import record_chat_success, record_chat_error
from pydantic import BaseModel

# ---------- Config ----------

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4.1-mini")

PROFILE_DIR = Path(__file__).parent / "profiles"

# ---------- Models ----------

class ChatRequest(BaseModel):
    user_id: str
    text: str
    profile: Optional[str] = "general"

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

def get_profile(name: Optional[str]) -> dict:
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


# ---------- Persona Memory ----------

PERSONA_DIR = Path(__file__).resolve().parent / "data" / "persona"
if not PERSONA_DIR.exists():
    PERSONA_DIR = Path(__file__).resolve().parent / "profiles"

def load_persona_memory() -> dict[str, dict]:
    memory: dict[str, dict] = {}
    if not PERSONA_DIR.exists():
        return memory

    for p in PERSONA_DIR.glob("*.yaml"):
        try:
            with p.open("r", encoding="utf-8") as f:
                data = yaml.safe_load(f) or {}
        except Exception as e:
            data = {"error": str(e)}
        memory[p.stem] = data
    return memory


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
from routes.memory import router as memory_router
from routes.pgvector_store import router as pgvector_router
app.include_router(memory_router)
app.include_router(pgvector_router)


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
    base_system_prompt = profile.get("system_prompt", "You are a helpful assistant for Ross.")
    profile_name = profile.get("name", req.profile or "unknown")

    # Load persona memory (ross_profile, kids_hq)
    try:
        persona_memory = load_persona_memory()
    except Exception:
        persona_memory = {}

    persona_snippet_parts = []
    if "ross_profile" in persona_memory:
        persona_snippet_parts.append(
            "Ross persona (YAML): " +
            json.dumps(persona_memory["ross_profile"], ensure_ascii=False)
        )
    if "kids_hq" in persona_memory:
        persona_snippet_parts.append(
            "Kids info (YAML): " +
            json.dumps(persona_memory["kids_hq"], ensure_ascii=False)
        )

    persona_snippet = "\n\n".join(persona_snippet_parts)
    system_prompt = base_system_prompt + (
        "\n\nPersistent private memory (StaffordOS):\n" + persona_snippet
        if persona_snippet else ""
    )

    user_prompt = req.text

    try:
        reply = call_openai_chat(system_prompt, user_prompt)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Orchestrator LLM error: {e}")

    return ChatResponse(reply=reply, profile=profile_name)



# StaffordOS status router (auto-added)
try:
    import status as stafford_status
    app.include_router(stafford_status.router)
except Exception as e:  # pragma: no cover
    print("Warning: failed to load status router:", e)

# StaffordOS parallel_debug router (auto-added)
try:
    import parallel_debug as stafford_parallel_debug
    app.include_router(stafford_parallel_debug.router)
except Exception as e:  # pragma: no cover
    print("Warning: failed to load parallel_debug router:", e)


# StaffordOS parallel retrieval router (auto-added)
try:
    import retrieval_parallel as _retrieval_parallel
    app.include_router(_retrieval_parallel.router)
except Exception as e:  # pragma: no cover
    print("Warning: failed to load retrieval_parallel router:", e)


# StaffordOS task decomposition router (auto-added)
try:
    import tasks_decompose as _tasks_decompose
    app.include_router(_tasks_decompose.router)
except Exception as e:  # pragma: no cover
    print("Warning: failed to load tasks_decompose router:", e)


# StaffordOS plan router (auto-added)
try:
    import plan as _plan
    app.include_router(_plan.router)
except Exception as e:  # pragma: no cover
    print("Warning: failed to load plan router:", e)


# StaffordOS execution_log router (auto-added)
try:
    import execution_log as _execution_log
    app.include_router(_execution_log.router)
except Exception as e:  # pragma: no cover
    print("Warning: failed to load execution_log router:", e)


# StaffordOS metrics router (auto-added)
try:
    import metrics as _metrics
    app.include_router(_metrics.router)
except Exception as e:  # pragma: no cover
    print("Warning: failed to load metrics router:", e)
