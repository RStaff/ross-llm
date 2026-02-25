from typing import Dict, Any

"""
Tenant + profile layout for Ross-LLM.

Tenants (hard walls):
- personal : Ross's life, health, kids, emotional processing, personal growth.
- smedia   : Stafford Media AI (umbrella agency + strategy + content).
- abando   : Abando product, customers, infra, marketing.
- seriti   : Seriti / EmpathAI – employee <> employer outcomes.
- nka      : No Kings Athletics brand, merch, campaigns.
- legal    : Legal organization, timelines, docs (no legal advice).

Profiles live *inside* one tenant and never cross them.
"""

TENANT_PROFILES: Dict[str, Dict[str, Any]] = {
    # ───────────────
    # PERSONAL LIFE
    # ───────────────
    "general": {
        "tenant": "personal",
        "description": (
            "Default Ross-LLM assistant for Ross's personal life. "
            "Use for planning days, emotional processing, big-picture life strategy."
        ),
        "tags": ["personal", "life", "planning", "reflection"],
    },
    "health-ops": {
        "tenant": "personal",
        "description": (
            "Health, nervous system, workouts, sleep, and recovery. "
            "Helps plan routines that support long-term resilience."
        ),
        "tags": ["health", "wellness", "routines"],
    },
    "kids-life": {
        "tenant": "personal",
        "description": (
            "Grace and Maya: memories, important dates, school events, and logistics. "
            "Use for planning trips, calls, visits, and capturing key moments."
        ),
        "tags": ["kids", "family", "grace", "maya"],
    },

    # ───────────────
    # STAFFORD MEDIA AI (UMBRELLA BUSINESS)
    # ───────────────
    "smedia-strategy": {
        "tenant": "smedia",
        "description": (
            "High-level Stafford Media AI strategy: offers, pricing, roadmap, partnerships, "
            "and how all products (Abando, Seriti, etc.) fit under the umbrella."
        ),
        "tags": ["business", "strategy", "stafford-media"],
    },
    "smedia-marketing": {
        "tenant": "smedia",
        "description": (
            "Stafford Media AI marketing: website copy, content calendar, email sequences, "
            "lead magnets, and campaign ideas."
        ),
        "tags": ["marketing", "content", "funnels"],
    },
    "smedia-ops": {
        "tenant": "smedia",
        "description": (
            "Operations for Stafford Media AI: client onboarding, SOPs, automation ideas, "
            "internal tooling, and delivery processes."
        ),
        "tags": ["operations", "systems", "automation"],
    },

    # ───────────────
    # ABANDO PRODUCT
    # ───────────────
    "abando-dev": {
        "tenant": "abando",
        "description": (
            "Abando engineering: stack, infra, CI/CD, feature design, bug triage, "
            "and technical roadmap."
        ),
        "tags": ["abando", "dev", "infra", "product"],
    },
    "abando-ops": {
        "tenant": "abando",
        "description": (
            "Abando operations + growth: onboarding merchants, pricing tiers, support flows, "
            "analytics, and retention strategies."
        ),
        "tags": ["abando", "ops", "growth", "merchants"],
    },

    # ───────────────
    # SERITI / EMPATHAI
    # ───────────────
    "seriti-product": {
        "tenant": "seriti",
        "description": (
            "Seriti / EmpathAI product thinking: what it does for employees and employers, "
            "feature sets, data boundaries, and outcomes."
        ),
        "tags": ["seriti", "product", "empathy", "workplace"],
    },
    "seriti-research": {
        "tenant": "seriti",
        "description": (
            "Seriti research: reading notes, frameworks on burnout, empathy at work, "
            "org design, and ethical AI in HR contexts."
        ),
        "tags": ["seriti", "research", "ethics"],
    },

    # ───────────────
    # NO KINGS ATHLETICS
    # ───────────────
    "nka-brand": {
        "tenant": "nka",
        "description": (
            "No Kings Athletics brand and merch: slogans, drops, campaigns, and community. "
            "Use for creative direction and launch planning."
        ),
        "tags": ["nka", "brand", "merch"],
    },

    # ───────────────
    # LEGAL ORGANIZATION (NO ADVICE)
    # ───────────────
    "legal-ops": {
        "tenant": "legal",
        "description": (
            "Legal organization and logistics: timelines, document indexes, task lists, "
            "and communication planning. Does NOT provide legal advice."
        ),
        "tags": ["legal", "organization", "logistics"],
    },
    "legal-journal": {
        "tenant": "legal",
        "description": (
            "Space to narrate events and feelings around legal matters in a structured way, "
            "so they can be summarized and organized later. No advice, just structure."
        ),
        "tags": ["legal", "journal", "timeline"],
    },
}


def get_tenant_for_profile(profile: str) -> str:
    data = TENANT_PROFILES.get(profile)
    if not data:
        raise KeyError(f"Unknown profile: {profile}")
    return data["tenant"]


def list_profiles() -> Dict[str, Dict[str, Any]]:
    return TENANT_PROFILES
