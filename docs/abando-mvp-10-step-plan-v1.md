# Abando MVP – 10-Step Engineering & Launch Plan (January Shopify Launch)

Source: `docs/abando-mvp-scope-v1.md`  
Owner: Ross Stafford (Founder, PM, Product)  
Target: Abando MVP live for real Shopify merchants in January

---

## Step 1 – Finalize MVP scope & tech stack

**Owner:** Ross  
**Goal:** No ambiguity about “what’s in” for January.

- [ ] Confirm the MVP scope in `docs/abando-mvp-scope-v1.md` is final for January.
- [ ] Lock tech stack for MVP:
  - Backend: Node/Express or Python/FastAPI (whatever Abando backend uses today).
  - DB: Postgres (recommended) or existing DB.
  - Message channel for MVP: **pick ONE** (email or on-site widget).
  - LLM provider + model for recovery copy.
- [ ] Create `docs/abando-tech-stack-v1.md` summarizing these choices.
- [ ] Define non-goals explicitly (multi-channel sequences, deep segmentation, etc.) to protect timeline.

**Exit criteria:** Scope + stack documented and not changing weekly.

---

## Step 2 – Shopify app skeleton & OAuth install flow

**Owner:** Ross + future collaborator dev (if/when added)  
**Goal:** Merchant can install Abando from Shopify and see a “connected” confirmation.

- [ ] Set up a Shopify Partner test app for Abando.
- [ ] Implement OAuth install flow:
  - [ ] Handle Shopify’s auth redirect.
  - [ ] Store shop domain, access token, and merchant identifier securely.
- [ ] After successful install, show a **simple “Abando is connected” screen**.
- [ ] Add basic error handling for failed installs and log them.

**Exit criteria:** Abando app can be installed on a dev store and shows a confirmation page.

---

## Step 3 – Abandoned cart event pipeline (MVP)

**Owner:** Ross  
**Goal:** Capture abandoned cart events in a clean, queryable way.

- [ ] Register webhooks for:
  - [ ] Checkout started / updated.
  - [ ] Order completed.
- [ ] Design DB schema for MVP:
  - [ ] `merchants`
  - [ ] `abandoned_carts` (with checkout ID, cart items, timestamps)
  - [ ] `recovery_messages` (message content, channel, status)
  - [ ] `recovered_orders` (link back to `abandoned_carts`)
- [ ] Implement webhook handlers that:
  - [ ] Detect when a checkout “goes stale” (abandoned).
  - [ ] Mark carts as recovered if an order completes after a recovery message.
- [ ] Log all webhook deliveries and failures.

**Exit criteria:** You can see a test cart move through: “abandoned → recovery message sent → recovered”.

---

## Step 4 – Recovery message engine (LLM-backed, single channel)

**Owner:** Ross  
**Goal:** One **opinionated**, reliable recovery flow using AI.

- [ ] Choose the primary MVP channel:
  - [ ] Email OR on-site widget (no multi-channel yet).
- [ ] Implement LLM prompt template:
  - Inputs:
    - Store name
    - Cart items (titles, maybe prices)
    - Merchant tone (“Friendly / Direct / Premium”)
  - Output:
    - A short, respectful recovery message with one clear CTA.
- [ ] Add a simple “tone” configuration for merchants.
- [ ] Implement sending logic:
  - [ ] Integrate with chosen email provider or on-site widget framework.
  - [ ] Store each send attempt in `recovery_messages`.
- [ ] Add guardrails:
  - [ ] Ensure no manipulative language.
  - [ ] Respect unsubscribes / basic opt-out.

**Exit criteria:** For one test store, abandoning a cart triggers **exactly one** clean recovery message.

---

## Step 5 – Merchant dashboard (MVP UI)

**Owner:** Ross  
**Goal:** Give merchants a simple, trustworthy view of Abando’s value.

- [ ] Create a minimal dashboard page (within the Shopify embedded app UI) showing:
  - [ ] Abandoned carts (count) over last 7 / 30 days.
  - [ ] Recovered carts (count) over last 7 / 30 days.
  - [ ] Revenue recovered ($) over last 7 / 30 days.
  - [ ] Current Abando status: ON / OFF.
- [ ] Add basic configuration section:
  - [ ] Toggle: Abando ON / OFF.
  - [ ] Tone selector: Friendly / Direct / Premium.
- [ ] Add links:
  - [ ] “How Abando uses your data” – plain-language, one page.
  - [ ] Support contact (email or form).

**Exit criteria:** A non-technical merchant can open the app and immediately understand:
- Is Abando on?
- Is it doing anything?
- Has it made me money?

---

## Step 6 – Connect Abando to StaffordOS monitoring

**Owner:** Ross  
**Goal:** Abando runs with the same observability discipline as Ross-LLM.

- [ ] For the Abando backend, mirror the pattern you used in StaffordOS:
  - [ ] Add a `/health` endpoint (basic status).
  - [ ] Add logging for key flows:
    - Webhook received.
    - Recovery message generated.
    - Message sent.
    - Order recovered.
  - [ ] Store logs in DB or a simple log file.
- [ ] Add an internal script like `abando-metrics` (even if it’s just a curl + `jq` wrapper) to get:
  - [ ] Number of webhooks received today.
  - [ ] Number of recovery messages sent.
  - [ ] Number of recovered orders.
- [ ] Optionally: Integrate high-level Abando metrics into StaffordOS later as a `/abando/metrics` endpoint.

**Exit criteria:** You can run a single command or hit a single endpoint to see if Abando is healthy and doing work.

---

## Step 7 – Internal QA and dogfooding

**Owner:** Ross  
**Goal:** Catch rough edges before real merchants hit them.

- [ ] Set up 1–2 dev stores for testing.
- [ ] Run structured test cases:
  - [ ] Abandon cart with 1 item.
  - [ ] Abandon cart with multiple items.
  - [ ] Abandon, then complete, ensuring it’s tracked as “recovered”.
  - [ ] Toggle Abando off and confirm no messages are sent.
  - [ ] Change tone setting and verify new messages reflect it.
- [ ] Log and triage all bugs in a simple `docs/abando-bugs-v1.md`.
- [ ] Fix only critical and high-impact issues for MVP.

**Exit criteria:** You can walk through 3–5 full end-to-end flows without surprises.

---

## Step 8 – Shopify App Store readiness

**Owner:** Ross  
**Goal:** Be ready to submit to the Shopify App Store review.

- [ ] Prepare listing assets (can reuse your existing brand kit work):
  - [ ] App icon(s)
  - [ ] Screenshots of the dashboard and flow.
  - [ ] Short demo GIF if possible.
- [ ] Write listing copy:
  - [ ] Clear one-liner value prop.
  - [ ] Who it’s for (small–mid Shopify merchants).
  - [ ] Key features (1–3 bullet points).
  - [ ] Privacy / data usage statement.
- [ ] Ensure all URLs are live:
  - [ ] Privacy policy.
  - [ ] Terms of service.
  - [ ] Support contact.
- [ ] Review Shopify requirements for app review and ensure compliance.

**Exit criteria:** You can submit the app for review without scrambling to write copy or policies.

---

## Step 9 – Launch video & onboarding content

**Owner:** Ross  
**Goal:** Have a clear, repeatable story for merchants.

- [ ] Script a short launch video for Shopify merchants:
  - [ ] Who you are and why you built Abando.
  - [ ] What problem it solves (carts left behind).
  - [ ] How to install and turn it on (in plain language).
  - [ ] 1–2 simple examples of recovered revenue.
- [ ] Record MVP version of the video (even if production value is simple).
- [ ] Create a one-page “Quick Start” PDF/Google Doc:
  - [ ] Install.
  - [ ] Turn on.
  - [ ] Interpret the dashboard.
- [ ] Add links to this content from:
  - [ ] Inside the app (Help / Getting Started).
  - [ ] Your website and future email outreach.

**Exit criteria:** A new merchant can understand and adopt Abando in < 30 minutes using your content.

---

## Step 10 – Pilot merchants, feedback loop, and v2 backlog

**Owner:** Ross  
**Goal:** Turn MVP into a learning machine, not just a product.

- [ ] Identify 3–5 pilot merchants (warm contacts, friendly intros, or small list-building).
- [ ] Offer clear terms:
  - [ ] Early access.
  - [ ] Maybe discounted or free for 60–90 days in exchange for feedback.
- [ ] For each pilot:
  - [ ] Install Abando together over Zoom (if possible).
  - [ ] Set expectations for check-in cadence (e.g., every 2–3 weeks).
  - [ ] Track:
    - [ ] Recovered revenue.
    - [ ] Merchant happiness / confusion points.
- [ ] Capture feedback in `docs/abando-v2-backlog.md`:
  - [ ] Multi-channel ideas.
  - [ ] Advanced targeting / segments.
  - [ ] Better messaging controls.
- [ ] Decide on 2–3 **v2 bets** based on real usage, not guesses.

**Exit criteria:** At least one merchant recovers >$500 and you have a clear, prioritized v2 backlog grounded in real feedback.

---

## Suggested Timeline (High-Level)

- **Week 1–2:** Steps 1–3 (scope, Shopify skeleton, event pipeline)
- **Week 3:** Steps 4–5 (message engine + dashboard)
- **Week 4:** Steps 6–7 (monitoring + QA)
- **Week 5:** Steps 8–9 (listing + launch content)
- **Week 6+:** Step 10 (pilots, feedback, v2 planning)

