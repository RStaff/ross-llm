#!/usr/bin/env bash
set -euo pipefail

echo "🏗  Initializing StaffordOS architecture v1..."
ROOT="$HOME/projects/ross-llm"

mkdir -p "$ROOT/config"
mkdir -p "$ROOT/memory"
mkdir -p "$ROOT/docs"

########################################
# 1) Modes config
########################################
cat << 'YAML' > "$ROOT/config/staffordos_modes.yaml"
# StaffordOS Modes Configuration v1
# This file defines the 4 core operational modes for Ross-LLM / StaffordOS.

modes:
  personal_hq:
    description: >
      Core personal operating system for Ross: family, health, trauma boundaries,
      energy constraints, values, and daily/weekly planning.
    default_profile: general
    memory_files:
      - memory/personal_hq.yaml

  business_hq:
    description: >
      Business and product focus: Abando, Stafford Media, active clients,
      offers, pricing, and revenue goals.
    default_profile: business
    memory_files:
      - memory/business_hq.yaml

  career_hq:
    description: >
      Career navigation mode: FDE roles, data/AI/marketing systems roles,
      interview prep, and job search strategy when needed.
    default_profile: career
    memory_files:
      - memory/career_hq.yaml

  staffordos_dev:
    description: >
      Internal StaffordOS / Ross-LLM dev mode: architecture, scripts, ports,
      services, and system upgrade plans.
    default_profile: dev
    memory_files:
      - memory/staffordos_dev.yaml
YAML

echo "✅ Created config/staffordos_modes.yaml"

########################################
# 2) Personal HQ memory
########################################
cat << 'YAML' > "$ROOT/memory/personal_hq.yaml"
id: personal_hq
version: 1
description: >
  Core personal HQ for Ross Stafford. Family, health, trauma boundaries,
  energy rules, values, and 2025 focus.

identity:
  full_name: Ross M. Stafford
  roles:
    - father
    - founder
    - builder of StaffordOS (Ross-LLM)
    - digital marketing + AI systems practitioner
  core_values:
    - Show up first for Grace and Maya.
    - Build ethical, transparent AI.
    - Choose stable income with long-term freedom over quick chaos.
    - Protect sleep and nervous system during heavy work/legal days.
    - Prefer source-of-truth fixes over duct tape.

family:
  daughters:
    - name: Grace
      birthdate: 2016-12-21
      notes:
        - Deeper brown skin tone, long curly hair.
        - Respond best with calm, encouraging tone.
    - name: Maya
      birthdate: 2020-01-31
      notes:
        - Light brown skin tone, curly hair in ponytails.
        - Also needs calm, encouraging, gentle responses.
  parents:
    father:
      name: Franklin
      notes:
        - African American, born 1945 in Sumter, South Carolina.
        - History major, pledged Omega Psi Phi in 1964.
    mother:
      name: Joan
      notes:
        - Sicilian and Irish heritage.
        - Provided strong emotional foundation and love.
  siblings:
    - name: Thomas
      relation: older brother
      notes:
        - Also Omega Psi Phi (Omega Zeta chapter at Duke).

fraternity_legacy:
  organization: Omega Psi Phi Fraternity, Inc.
  ross_crossing_year: 1996
  ross_chapter: Tau Iota
  father_chapter:
    name: Rho (Johnson C. Smith University)
    approximate_year: 1946
  notes:
    - Ross-LLM "birthday" is treated as 2025-11-17 (Founders Day of Omega Psi Phi).

health_and_trauma:
  has_cptsd_related_trauma: true
  principles:
    - Protect sleep aggressively on heavy days (legal, conflict, long coding).
    - Avoid high-chaos environments when nervous system is taxed.
    - Build schedules with rest windows and low-friction transitions.
    - Recognize that legal + financial stress amplifies nervous system load.
  weekend_planning_rules:
    - Prioritize simple outdoor time with Grace and Maya.
    - Use calm, predictable transitions.
    - Prefer quality of presence over number of activities.
    - Build in rest for Ross (nap, quiet time) during kid screen/independent play.

focus_2025:
  - Land a stable data / AI / marketing systems role in MA (if needed).
  - Ship Abando to real merchants.
  - Evolve Ross-LLM / StaffordOS as a real tool, not a crutch.

interaction_style:
  general:
    - Direct, honest, low-BS.
    - Prefers systems thinking: roadmaps, playbooks, scripts, clear roles.
    - Likes source-of-truth changes instead of output patching.
  with_kids:
    - Always calm, encouraging, safe, and age-appropriate.
    - Avoid scary, adult, or heavy content with Grace and Maya.
YAML

echo "✅ Created memory/personal_hq.yaml"

########################################
# 3) Business HQ memory
########################################
cat << 'YAML' > "$ROOT/memory/business_hq.yaml"
id: business_hq
version: 1
description: >
  Business and product HQ. Stafford Media Consulting, Abando, and related products.

company:
  name: Stafford Media Consulting
  type: AI-driven digital marketing and automation agency
  mission: >
    Help small and medium-sized businesses use ethical AI, automation,
    and data to grow revenue without chaos.

products:
  - name: Abando
    type: SaaS
    description: AI-powered Shopify cart recovery / abandoned cart assistant.
    status:
      current: "MVP in progress; focus on getting first real merchants."
      priorities:
        - Stabilize deployment (Render/Vercel/Shopify app).
        - Finish multi-tier pricing behavior in Cart-Agent.
        - Implement safe, transparent AI messaging for merchants.
    brand:
      theme: black + gold wolf
      notes:
        - Emphasis on trust, transparency, and ethical AI.
  - name: Cart-Agent
    type: backend service
    description: >
      Operational agent that powers checkout / cart-related workflows
      for Abando and future products.
    status:
      current: "Backend logic and environment automation in progress."

clients_and_leads:
  current:
    - name: Chad / YPP
      type: automation / bot client
      status: "Active, paid."
  leads:
    - name: Beef jerky client
      status: "Lead / client in motion."
    - name: Bakery pitch
      status: "Prospect; strategy & offer development possible."

business_principles:
  - Build automation that actually reduces chaos for clients.
  - Focus on high-ROI, low-BS offers.
  - Prefer recurring / subscription revenue where possible.
  - Use transparent, ethical AI messaging as a competitive edge vs big tech.
YAML

echo "✅ Created memory/business_hq.yaml"

########################################
# 4) Career HQ memory
########################################
cat << 'YAML' > "$ROOT/memory/career_hq.yaml"
id: career_hq
version: 1
description: >
  Career strategy HQ for Ross. Used when external roles are active focus.

preferences:
  geography:
    primary_region: "Massachusetts (near Braintree) in the short term"
    long_term_goal: "Return to New Jersey to be closer to Grace and Maya"
  role_types:
    - data / BI / analytics roles
    - data / AI / marketing systems roles
    - technical project / program management
    - teaching roles (selective, values-aligned)
  constraints:
    - Must allow meaningful time and presence with Grace and Maya.
    - Prefer stability and benefits over short-term big swings.
    - Avoid roles that require constant high-intensity travel.

targets_example:
  - company: Harmony AI (or similar)
    role: Forward Deployed Engineer / AI project role
    status: "Lead / interview track in the past; similar roles are relevant."
  - company: CATS Academy
    role: Teaching / consulting
    status: "Values-aligned option; not primary focus unless conditions shift."

career_principles:
  - Career is a tool to protect and provide for family, not identity.
  - Prefer roles that align with AI, data, and systems thinking strengths.
  - Use StaffordOS as leverage (personal infrastructure) to ramp faster.
YAML

echo "✅ Created memory/career_hq.yaml"

########################################
# 5) StaffordOS Dev memory
########################################
cat << 'YAML' > "$ROOT/memory/staffordos_dev.yaml"
id: staffordos_dev
version: 1
description: >
  Internal StaffordOS / Ross-LLM dev memory. How the system is wired,
  where code lives, and how to restart / debug it.

repo:
  root: ~/projects/ross-llm
  key_scripts:
    - scripts/configure_openai_key.sh
    - scripts/staffordos_restart.sh
    - scripts/staffordos_boot.sh
    - scripts/staffordos_integrity_test.sh
  notes:
    - Ross prefers source-of-truth fixes in code / config over output patching.
    - Avoid manual, one-off hacks; automate with scripts.

services:
  orchestrator:
    path: apps/orchestrator
    dev_server:
      command: uvicorn main:app --port 8000 --reload
      url: http://127.0.0.1:8000
    health_endpoint: /health
  gateway_cli:
    script: ./ross.sh
    description: >
      CLI entrypoint to send messages to Ross-LLM router and orchestrator.
    example_usage:
      - 'ross "Who are my daughters?"'
      - 'ross "Quick ping from general profile."'

openai:
  key_storage:
    path: ~/.config/ross-llm/openai_api_key
    notes:
      - Key is loaded via scripts/openai_env.sh and staffordos_boot.sh.
      - Avoid hardcoding keys in scripts or code.
  test_procedure:
    - Run scripts/staffordos_integrity_test.sh
    - Confirm orchestrator health at /health
    - Confirm memory reload via /admin/reload-memory

operational_principles:
  - Always provide Ross cut-and-paste scripts in correct execution order.
  - Prefer idempotent scripts (safe to re-run).
  - Once something works (key loading, memory), do not disturb it casually.
  - Document architecture and decisions in docs/ for Future Ross.
YAML

echo "✅ Created memory/staffordos_dev.yaml"

########################################
# 6) Architecture README
########################################
cat << 'MD' > "$ROOT/docs/README_STAFFORDOS_ARCHITECTURE.md"
# StaffordOS Architecture v1

## Core Idea

StaffordOS is Ross's personal operating system built on top of Ross-LLM.
It has four core operational modes, each backed by structured YAML memory:

1. **personal_hq** – family, health, trauma boundaries, energy, values, and 2025 focus.
2. **business_hq** – Abando, Stafford Media, products, clients, and revenue goals.
3. **career_hq** – career strategy, roles, constraints, and target companies.
4. **staffordos_dev** – how StaffordOS itself works (scripts, ports, services, tests).

## Files Created in v1

- `config/staffordos_modes.yaml` – defines the modes and which memory files each uses.
- `memory/personal_hq.yaml` – Ross's personal HQ memory.
- `memory/business_hq.yaml` – business / product HQ memory.
- `memory/career_hq.yaml` – career HQ memory.
- `memory/staffordos_dev.yaml` – internal dev / ops memory.
- `docs/README_STAFFORDOS_ARCHITECTURE.md` – this document.

## How It Fits Into Ross-LLM

- The **orchestrator** and **router** already exist.
- `/admin/reload-memory` should (now or later) load these YAML files so that
  queries like "Who are my daughters?" or "What are my 2025 focus areas?"
  are answered from this structured, versioned data.
- The CLI command `ross "..."` is the main way Ross interacts with StaffordOS.

## Next Evolution Steps (Future Work)

1. **Intent → Mode Routing**
   - Map incoming messages to one of the four modes based on intent
     (personal, business, career, dev).

2. **Mode-Aware Prompts**
   - Use different system prompts or context windows per mode
     to keep answers aligned with Ross's values.

3. **Dashboards / Status Views**
   - Add commands like:
     - `ross "Show me my business_hq summary."`
     - `ross "Summarize personal_hq for today."`

4. **Agent Layers (Later)**
   - Once the modes + memory are stable, add agent workflows per mode
     (e.g., Abando deployment agent, career application agent, etc.).

This v1 architecture is intentionally simple: it provides a clean,
human-editable core that Ross can update over time, while StaffordOS
handles orchestration and reasoning on top of it.
MD

echo "✅ Created docs/README_STAFFORDOS_ARCHITECTURE.md"

echo ""
echo "🎉 StaffordOS architecture v1 initialized."
echo "   Files created:"
echo "     - config/staffordos_modes.yaml"
echo "     - memory/personal_hq.yaml"
echo "     - memory/business_hq.yaml"
echo "     - memory/career_hq.yaml"
echo "     - memory/staffordos_dev.yaml"
echo "     - docs/README_STAFFORDOS_ARCHITECTURE.md"
echo ""
echo "Next suggested steps:"
echo "  1) git status          # review changes"
echo "  2) git diff            # sanity check content"
echo "  3) ./ross.sh \"Summarize my personal_hq.yaml\""
echo "  4) ./ross.sh \"Summarize my business_hq.yaml\""
