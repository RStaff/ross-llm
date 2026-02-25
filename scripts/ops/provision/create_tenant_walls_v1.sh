#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "🏗  Ross-LLM Tenant Wall Level-Up v1"
echo "   (Personal / Abando / Seriti / ProSe hard separation)"
echo

# 1) Backup current orchestrator main.py
STAMP=$(date +"%Y%m%d_%H%M%S")
if [[ -f apps/orchestrator/main.py ]]; then
  cp apps/orchestrator/main.py "apps/orchestrator/main.py.bak_tenants_${STAMP}"
  echo "🛟 Backed up apps/orchestrator/main.py -> apps/orchestrator/main.py.bak_tenants_${STAMP}"
else
  echo "⚠️ apps/orchestrator/main.py not found (continuing, new file will be created)."
fi
echo

# 2) Write tenant_config.py with all profiles & tenants
echo "🧱 Writing apps/orchestrator/tenant_config.py …"

cat <<'PY' > apps/orchestrator/tenant_config.py
from typing import Dict, Any, List

# High-level tenant definition:
# - "personal": your life, health, finance, family, career, etc.
# - "abando"  : Abando product + customers + infra.
# - "seriti"  : Seriti / EmpathAI workspace for employee & org outcomes.
# - "prose"   : Pro Se / legal tools (timeline building, document prep, etc.).

TENANT_PROFILES: Dict[str, Dict[str, Any]] = {
    # ───────────────
    # PERSONAL LIFE
    # ───────────────
    "general": {
        "tenant": "personal",
        "description": (
            "Default Ross-LLM assistant for Ross's life. "
            "Focus on balance, planning, automation, and long-term goals."
        ),
        "namespaces": [
            "personal_general",
            "personal_plans",
            "personal_journal",
        ],
        "allowed_tools": [
            "notes",
            "task_planning",
            "career_planning",
        ],
    },
    "legal-ops": {
        "tenant": "prose",
        "description": (
            "Legal ops / Pro Se support: organize facts, timelines, exhibits. "
            "NO direct legal advice, just structure and clarity."
        ),
        "namespaces": [
            "legal_cases",
            "legal_timelines",
            "legal_exhibits",
        ],
        "allowed_tools": [
            "legal_summary",
            "timeline_builder",
            "document_outline",
        ],
    },
    "health-wellness": {
        "tenant": "personal",
        "description": (
            "Health, wellness, and nervous-system regulation. "
            "Focus on habits, tracking, and emotional regulation."
        ),
        "namespaces": [
            "health_notes",
            "health_habits",
        ],
        "allowed_tools": [
            "habit_tracker",
            "reflection",
        ],
    },
    "finance-ops": {
        "tenant": "personal",
        "description": (
            "Personal finance, cashflow, long-term planning (non-investment advice)."
        ),
        "namespaces": [
            "finance_notes",
            "finance_plans",
        ],
        "allowed_tools": [
            "budget_planning",
            "scenario_planning",
        ],
    },

    # ───────────────
    # FAMILY / KIDS
    # ───────────────
    "grace-life": {
        "tenant": "personal",
        "description": "Memory lane and planning for Grace (events, milestones, letters).",
        "namespaces": [
            "family_grace",
        ],
        "allowed_tools": [
            "memory_log",
            "event_planning",
        ],
    },
    "maya-life": {
        "tenant": "personal",
        "description": "Memory lane and planning for Maya (events, milestones, letters).",
        "namespaces": [
            "family_maya",
        ],
        "allowed_tools": [
            "memory_log",
            "event_planning",
        ],
    },

    # ───────────────
    # ABANDO (PRODUCT)
    # ───────────────
    "abando-dev": {
        "tenant": "abando",
        "description": (
            "Abando dev + infra: architecture, scripts, CI/CD, Render/Vercel/K8s, "
            "feature planning, experiments. No live customer PII."
        ),
        "namespaces": [
            "abando_arch",
            "abando_dev_docs",
            "abando_infra",
        ],
        "allowed_tools": [
            "dev_notes",
            "ticket_drafts",
            "infra_playbooks",
        ],
    },
    "abando-prod": {
        "tenant": "abando",
        "description": (
            "Abando production behavior, anonymized events, funnels, copy tests. "
            "No personal life data, no raw customer PII."
        ),
        "namespaces": [
            "abando_events",
            "abando_metrics",
            "abando_copy",
        ],
        "allowed_tools": [
            "growth_ideas",
            "copywriter",
            "journey_mapper",
        ],
    },

    # ───────────────
    # SERITI / EMPATHAI
    # ───────────────
    "seriti-research": {
        "tenant": "seriti",
        "description": (
            "Seriti / EmpathAI concepting, research, positioning, and product ideas. "
            "Employee well-being, outcomes, and org trust."
        ),
        "namespaces": [
            "seriti_research",
            "seriti_product",
        ],
        "allowed_tools": [
            "ideation",
            "research_synthesis",
        ],
    },

    # ───────────────
    # AUTOMATE WITH ROSS / STAFFORD MEDIA AI
    # ───────────────
    "smedia-automation": {
        "tenant": "personal",
        "description": (
            "Stafford Media AI / Automate with Ross. Demos, client playbooks, "
            "automation patterns, course notes."
        ),
        "namespaces": [
            "smedia_automation",
            "smedia_demos",
        ],
        "allowed_tools": [
            "demo_planner",
            "case_study_builder",
        ],
    },
}


def list_profiles() -> List[dict]:
    """Return a list of profiles + metadata for the /profiles endpoint."""
    items = []
    for name, cfg in TENANT_PROFILES.items():
        items.append(
            {
                "name": name,
                "tenant": cfg["tenant"],
                "description": cfg.get("description", ""),
                "namespaces": cfg.get("namespaces", []),
                "allowed_tools": cfg.get("allowed_tools", []),
            }
        )
    return items


def get_profile_config(profile: str) -> Dict[str, Any]:
    """Get config for a given profile or raise a clear error."""
    key = profile or "general"
    if key not in TENANT_PROFILES:
        raise ValueError(f"Unknown profile: {key}")
    return TENANT_PROFILES[key]
PY

echo "✅ apps/orchestrator/tenant_config.py written."
echo

# 3) Rewrite orchestrator main.py with tenant-aware chat
echo "🧠 Writing tenant-aware apps/orchestrator/main.py …"

cat <<'PY' > apps/orchestrator/main.py
import os
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from openai import OpenAI

from .tenant_config import list_profiles, get_profile_config

app = FastAPI(title="Ross-LLM Orchestrator", version="1.0.0")

# OpenAI client configuration
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
OPENAI_MODEL = os.environ.get("OPENAI_MODEL", "gpt-4.1-mini")
OPENAI_PROJECT = os.environ.get("OPENAI_PROJECT")

if not OPENAI_API_KEY:
    # In practice you'll want to fail fast here, but we keep it soft for dev.
    print("⚠️ OPENAI_API_KEY not set. Orchestrator will fail on real calls.")

_client_kwargs = {"api_key": OPENAI_API_KEY}
if OPENAI_PROJECT:
    _client_kwargs["project"] = OPENAI_PROJECT

client = OpenAI(**_client_kwargs)


class ChatRequest(BaseModel):
    user_id: str
    text: str
    profile: Optional[str] = "general"


class ChatResponse(BaseModel):
    reply: str
    profile: str
    tenant: str


@app.get("/health")
async def health():
    return {"ok": True}


@app.get("/profiles")
async def profiles():
    """Introspection: which profiles exist and what they can touch."""
    return {"profiles": list_profiles()}


def build_system_prompt(profile: str, tenant: str, description: str, namespaces, allowed_tools):
    """
    Build a strict system prompt that:
    - Keeps Ross-LLM in-role.
    - Enforces tenant separation at the prompt level.
    - Summarizes what this profile is for.
    """
    ns_str = ", ".join(namespaces) if namespaces else "none"
    tools_str = ", ".join(allowed_tools) if allowed_tools else "none"

    return f"""You are Ross-LLM, a personal and product AI assistant for Ross Stafford.

You are currently operating under the profile: '{profile}' in tenant: '{tenant}'.

High-level rules:
- Tenant boundaries are STRICT:
  - You MAY ONLY reason about and use information that belongs to this tenant.
  - Do NOT reference, speculate about, or request data from other tenants.
  - If the user asks for something that should be in another tenant, explain that
    and suggest they call the correct profile instead.

Tenant summary:
- Tenant: {tenant}
- Profile description: {description}
- Allowed logical namespaces (RAG / memory buckets): {ns_str}
- Allowed logical tools: {tools_str}

Behavior:
- Answer clearly, with structure, and favor automation, scripts, and checklists.
- Be calm and stabilizing. If Ross sounds overwhelmed, help him prioritize.
- Never fabricate legal, medical, or financial *advice*. You can help organize
  information, risks, and questions to ask real professionals.

If a request conflicts with these rules, refuse gently and explain why."""
    

@app.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    # 1) Resolve profile → tenant config
    try:
        cfg = get_profile_config(req.profile or "general")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    tenant = cfg["tenant"]
    description = cfg.get("description", "")
    namespaces = cfg.get("namespaces", [])
    allowed_tools = cfg.get("allowed_tools", [])

    # 2) Build system prompt
    system_prompt = build_system_prompt(
        profile=req.profile or "general",
        tenant=tenant,
        description=description,
        namespaces=namespaces,
        allowed_tools=allowed_tools,
    )

    if not OPENAI_API_KEY:
        # For development without a key, echo instead of calling OpenAI
        echo = (
            "[DEV ECHO – no OPENAI_API_KEY set]\n\n"
            f"Profile: {req.profile or 'general'} (tenant: {tenant})\n"
            f"User said: {req.text}"
        )
        return ChatResponse(reply=echo, profile=req.profile or "general", tenant=tenant)

    # 3) Call OpenAI with tenant-aware system prompt
    try:
        completion = client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": req.text},
            ],
        )
        reply_text = completion.choices[0].message.content or ""
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Orchestrator LLM error: {exc}")

    return ChatResponse(
        reply=reply_text,
        profile=req.profile or "general",
        tenant=tenant,
    )
PY

echo "✅ apps/orchestrator/main.py written."
echo

# 4) Rebuild and restart the stack so the new walls are live
echo "🐳 Rebuilding & restarting Ross-LLM stack with tenant walls…"
docker compose up -d --build

echo
echo "⏳ Checking health endpoints…"
sleep 2
set +e
curl -s http://localhost:8000/health && echo "✅ Gateway healthy (port 8000)"
curl -s http://localhost:8000/health && echo "✅ Orchestrator healthy (port 8000)"
set -e

echo
echo "✅ Tenant walls installed."
echo "   You can inspect profiles with:"
echo "     curl -s http://localhost:8000/profiles | jq"
echo
echo "   And test chats with your existing helper script, e.g.:"
echo "     ./ross_llm_chat.sh \"Give me a 3-task priority list across Abando and Ross-LLM.\" general"
echo "     ./ross_llm_chat.sh \"List top infra tasks for Abando this week.\" abando-dev"
echo "     ./ross_llm_chat.sh \"Help me plan next legal prep block.\" legal-ops"
