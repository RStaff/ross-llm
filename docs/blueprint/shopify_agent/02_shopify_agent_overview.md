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
