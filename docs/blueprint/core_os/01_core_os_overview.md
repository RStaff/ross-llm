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
