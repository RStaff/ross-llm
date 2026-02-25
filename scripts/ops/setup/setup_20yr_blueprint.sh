#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/projects/ross-llm"
cd "$ROOT"

echo "🧱 Creating 20-year blueprint scaffolding under $ROOT"

# Core blueprint folders
mkdir -p docs/blueprint/{core_os,shopify_agent,devops_agent,life_archive,swarm}/specs
mkdir -p docs/blueprint/status

########################################
# 0. Vision & principles
########################################
cat > docs/blueprint/00_vision_and_principles.md <<'MD'
# Ross-LLM – Long-Horizon Blueprint (No Fixed Timeline)

This repo is the **root OS** for Ross’s future agents and AI products.

**Principles:**
- No fixed years. Progress is **phase-based**, not time-based.
- Automate everything twice: once for Ross, once for clients.
- Source-of-truth lives in **this repo**, never only in someone’s head.
- AI is a *team member*, not a toy: every feature must reduce real cognitive or operational load.

**Core Pillars:**
1. Personal AI OS (Ross-LLM Core)
2. Shopify / Abando Autonomous Agent
3. DevOps / Infra Agent
4. Life Archive & Therapy Companion
5. Agent Swarm / Orchestrator (future control plane)

Use this file only to refine **why** you’re building, not the technical details.
MD

########################################
# 1. Personal AI OS (Core)
########################################
cat > docs/blueprint/core_os/01_core_os_overview.md <<'MD'
# Pillar 1 – Personal AI OS (Ross-LLM Core)

Goal: Make Ross-LLM the **default interface** for Ross’s brain, projects, and life decisions.

**Core Capabilities (Target):**
- Persistent memory across:
  - Legal (Whole Foods + future cases)
  - Business (Abando, NKA, Stafford Media)
  - Career & jobs
  - Family & life events
- Profiles for:
  - general, abando-dev, legal-ops, life-coach, builder, etc.
- Retrieval:
  - store & fetch notes, decisions, and summaries via embeddings + Postgres/pgvector
- Interfaces:
  - CLI (`ross_llm_chat.sh`)
  - HTTP API for future UIs (web, mobile, voice)

**Next concrete upgrades (Phase-based, not time-based):**
- Phase A:
  - [ ] Add `life-coach` profile that knows your values and goals.
  - [ ] Add endpoints to save “key moments” as long-term notes.
- Phase B:
  - [ ] Build a simple web UI (single-page) on top of gateway.
- Phase C:
  - [ ] Add scheduled agents (cron/worker) that review your week and summarize it.
MD

########################################
# 2. Shopify / Abando Agent
########################################
cat > docs/blueprint/shopify_agent/02_shopify_agent_overview.md <<'MD'
# Pillar 2 – Shopify / Abando Autonomous Agent

Goal: Evolve **Abando** from a smart app into a **store-side agent** that feels like an employee.

**Core Capabilities (Target):**
- Connects to Shopify store data (carts, orders, customers).
- Uses LLM + rules to:
  - Draft recovery emails / SMS.
  - Suggest discounts intelligently.
  - Run simple A/B tests on subject lines or offers.
- Reports back to merchant in plain language:
  - "I recovered $X this week."
  - "Top 3 failing funnels and my suggested fixes."

**Future Agent Behavior:**
- Watches store events in real-time.
- Adjusts strategies based on performance.
- Explains *why* it made choices (“transparent AI employee”).

**Next concrete upgrades (Phase-based):**
- Phase A:
  - [ ] Document current Abando stack and data flows here.
  - [ ] Define simple JSON interface: `store_state -> agent_action`.
- Phase B:
  - [ ] Implement a “Recovery Plan” generator using Ross-LLM as backend.
- Phase C:
  - [ ] Ship v1 to 1–3 real merchants and record outcomes here.
MD

########################################
# 3. DevOps / Infra Agent
########################################
cat > docs/blueprint/devops_agent/03_devops_agent_overview.md <<'MD'
# Pillar 3 – DevOps / Infra Agent

Goal: Build an agent that keeps Ross’s infra stable:
- Render, Kubernetes (future), Docker, GitHub, CI/CD, alerts.

**Core Capabilities (Target):**
- Knows:
  - How to restart Ross-LLM stack safely.
  - Where logs live.
  - How to inspect failing builds.
- Can:
  - Propose pipeline/YAML changes (PR-ready).
  - Generate runbooks when things break.
  - Track **costs** across services (Render, Vercel, etc.).

**Next concrete upgrades:**
- Phase A:
  - [ ] Document current infra map (Render, Docker, any K8s).
  - [ ] Create a `devops-agent` profile hooked into Ross-LLM that:
    - Reads build logs you paste.
    - Suggests fixes in a structured format.
- Phase B:
  - [ ] Add scripts that export logs into a file `logs/devops/*.log` for easy ingestion.
- Phase C:
  - [ ] Move a simple service (e.g., a status API) to Kubernetes with IaC, assisted by the agent.
MD

########################################
# 4. Life Archive & Therapy Companion
########################################
cat > docs/blueprint/life_archive/04_life_archive_overview.md <<'MD'
# Pillar 4 – Life Archive & Therapy Companion

Goal: Turn Ross-LLM into a **trusted witness** and gentle coach:
- Tracks growth, patterns, and emotional load.
- Never gaslights your experience.
- Always orients you back to your mission and your daughters.

**Core Capabilities (Target):**
- Store:
  - Key memories (childhood, marriage, divorce, wins, traumas).
  - Ongoing notes about emotional states.
- Retrieve:
  - “Show me patterns over the last 30 days.”
  - “What helps when I feel triggered like this?”
- Reflect:
  - Weekly synthesis of how you’re growing.
  - Gentle reminders of boundaries and non-negotiables.

**Next concrete upgrades:**
- Phase A:
  - [ ] Add `life-archive` profile focused on calm reflection.
  - [ ] Decide format for “memory entries” (e.g. JSON + text in DB).
- Phase B:
  - [ ] Add a CLI command to log a new memory or reflection entry.
- Phase C:
  - [ ] Weekly “Life Review” prompt that you run manually at first.
MD

########################################
# 5. Agent Swarm / Orchestrator (future)
########################################
cat > docs/blueprint/swarm/05_swarm_overview.md <<'MD'
# Pillar 5 – Agent Swarm / Orchestrator (Future Control Plane)

Goal: Manage **multiple agents** (Abando, DevOps, Life, Legal, etc.) as a coordinated team.

**Core Ideas:**
- Each agent = specialized profile + tools.
- Swarm controller:
  - Knows who to assign a task to.
  - Tracks task state.
  - Logs outcomes to memory.

**Not for now, but soon:**
- Task routing:
  - From natural language to the right agent.
- Simple priority queue:
  - “Today focus on: cashflow, infra stability, legal deadlines.”

This file is a parking lot for concepts until the first 4 pillars have solid foundations.
MD

########################################
# 6. Status / Backlog
########################################
cat > docs/blueprint/status/roadmap_backlog.md <<'MD'
# Blueprint Backlog (Phase-Based, No Dates)

Use this file as a **living kanban**.

## NOW (Active)
- [ ] Make sure Ross-LLM start/stop is 1 command (`./start.sh`, `docker compose down`).
- [ ] Add or refine profiles: general, abando-dev, legal-ops, life-coach, devops-agent.
- [ ] Choose 1 pillar to push forward this week and add 3 concrete tasks under it.

## NEXT
- [ ] First real merchant using Abando as an “employee.”
- [ ] First full week of using Life Archive reflection daily.
- [ ] DevOps agent helps fix 1 real pipeline / deploy issue.

## LATER
- [ ] Simple web UI for Ross-LLM.
- [ ] Start Swarm controller design.
- [ ] Explore hosted Ross-LLM for trusted friends/clients.
MD

echo "✅ Blueprint scaffolding created under docs/blueprint"
