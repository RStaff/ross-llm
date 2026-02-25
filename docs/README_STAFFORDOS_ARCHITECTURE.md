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
