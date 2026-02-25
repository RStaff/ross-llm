#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "🏗  Ross-LLM Tenant Wall Level-Up v2"
echo "   (Personal / StaffordMedia / Abando / Seriti / NKA / ProSe)"
echo

# 1) Backup current orchestrator main.py (just in case)
STAMP=$(date +"%Y%m%d_%H%M%S")
if [[ -f apps/orchestrator/main.py ]]; then
  cp apps/orchestrator/main.py "apps/orchestrator/main.py.bak_tenants_${STAMP}"
  echo "🛟 Backed up apps/orchestrator/main.py -> apps/orchestrator/main.py.bak_tenants_${STAMP}"
else
  echo "⚠️ apps/orchestrator/main.py not found (continuing, new file will be created)."
fi

echo
echo "🧱 Writing apps/orchestrator/tenant_config.py …"

cat <<'PY' > apps/orchestrator/tenant_config.py
from typing import Dict, Any

# Tenants are the hard walls (domains):
# - personal       : Ross's life, health, finance, parenting, self-work
# - stafford_media : Stafford Media AI / agency / consulting
# - abando         : Abando product + infra + customers
# - seriti         : Seriti / EmpathAI product + research
# - nka            : No Kings Athletics clothing / lifestyle brand
# - prose          : Legal / Pro Se tooling (non-advice helpers)

TENANT_PROFILES: Dict[str, Dict[str, Any]] = {
    # ─────────────────
    # PERSONAL (Ross)
    # ─────────────────
    "general": {
        "tenant": "personal",
        "description": "Default Ross-LLM assistant for Ross's life, planning, and reflection.",
    },
    "health-wellbeing": {
        "tenant": "personal",
        "description": "Physical/mental health routines, sleep, exercise, and recovery.",
    },
    "life-events": {
        "tenant": "personal",
        "description": "Major life events, deadlines, appointments, and logistics.",
    },
    "grace-life": {
        "tenant": "personal",
        "description": "Planning, memories, and logistics related to Grace.",
    },
    "maya-life": {
        "tenant": "personal",
        "description": "Planning, memories, and logistics related to Maya.",
    },
    "personal-finance": {
        "tenant": "personal",
        "description": "Budgeting, cashflow, and long-term financial strategy for Ross.",
    },

    # ───────────────────────────
    # STAFFORD MEDIA AI (Agency)
    # ───────────────────────────
    "smedia-ops": {
        "tenant": "stafford_media",
        "description": "Agency operations, processes, and capacity planning.",
    },
    "smedia-sales": {
        "tenant": "stafford_media",
        "description": "Lead gen, offers, and sales scripts for Stafford Media AI.",
    },
    "smedia-marketing": {
        "tenant": "stafford_media",
        "description": "Content, campaigns, and brand for Stafford Media AI.",
    },
    "smedia-automation": {
        "tenant": "stafford_media",
        "description": "Internal automation and tooling for Stafford Media AI.",
    },

    # ─────────────
    # ABANDO
    # ─────────────
    "abando-dev": {
        "tenant": "abando",
        "description": "Architecture, code, and infra for Abando.",
    },
    "abando-product": {
        "tenant": "abando",
        "description": "Product strategy, pricing, and roadmap for Abando.",
    },
    "abando-go-to-market": {
        "tenant": "abando",
        "description": "Marketing, partnerships, and launch sequencing for Abando.",
    },

    # ─────────────
    # SERITI / EMPATHAI
    # ─────────────
    "seriti-research": {
        "tenant": "seriti",
        "description": "Research, frameworks, and IP for Seriti / EmpathAI.",
    },
    "seriti-product": {
        "tenant": "seriti",
        "description": "Product design, features, and roadmap for Seriti / EmpathAI.",
    },

    # ─────────────
    # NKA (No Kings Athletics — clothing / lifestyle)
    # ─────────────
    "nka-brand": {
        "tenant": "nka",
        "description": "Brand, storytelling, and merch strategy for No Kings Athletics clothing.",
    },
    "nka-campaigns": {
        "tenant": "nka",
        "description": "Launch ideas, drops, and promo campaigns for NKA apparel.",
    },
    "nka-forge": {
        "tenant": "nka",
        "description": "Forge ethos, training narratives, and content that supports the NKA brand.",
    },

    # ─────────────
    # LEGAL / PRO SE
    # ─────────────
    "legal-ops": {
        "tenant": "prose",
        "description": "Timeline building, document organization, and task planning for legal matters.",
    },
    "legal-diary": {
        "tenant": "prose",
        "description": "Structured reflections and logging around legal process and impact.",
    },
}

def get_profile_config(profile: str) -> Dict[str, Any]:
    if profile not in TENANT_PROFILES:
        raise ValueError(f"Unknown profile '{profile}'. Known profiles: {list(TENANT_PROFILES.keys())}")
    return TENANT_PROFILES[profile]
PY

echo "✅ Wrote apps/orchestrator/tenant_config.py"
echo

echo "🐳 Rebuilding and restarting Ross-LLM with tenant walls…"
docker compose up -d --build

echo "⏳ Checking health endpoints…"
sleep 2
set +e
curl -s http://localhost:8000/health && echo "✅ Gateway healthy (port 8000)"
curl -s http://localhost:8000/health && echo "✅ Orchestrator healthy (port 8000)"
set -e

echo
echo "✅ Tenant walls installed (v2)."
echo "   Inspect profiles with:"
echo "     curl -s http://localhost:8000/profiles | jq"
echo
echo "   Try chats like:"
echo "     ./ross_llm_chat.sh \"Help me plan my week across kids, job search, and health.\" general"
echo "     ./ross_llm_chat.sh \"List top 3 infra tasks for Abando this week.\" abando-dev"
echo "     ./ross_llm_chat.sh \"Draft a content theme plan for Stafford Media AI.\" smedia-marketing"
echo "     ./ross_llm_chat.sh \"Help me outline next steps for NKA merch.\" nka-brand"
echo "     ./ross_llm_chat.sh \"Help me organize my legal documents (no advice).\" legal-ops"
