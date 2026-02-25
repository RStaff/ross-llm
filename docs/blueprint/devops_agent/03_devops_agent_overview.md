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
