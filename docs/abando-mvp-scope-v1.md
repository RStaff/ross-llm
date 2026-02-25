# Abando MVP Scope – Shopify Launch (January)

## 1. Objective

Ship a focused Abando MVP that:
- Helps Shopify merchants **reduce abandoned carts** with a simple, transparent AI assistant.
- Is **fast to install**, **easy to understand**, and feels **ethically aligned** (no dark patterns).
- Is stable enough for real merchants and demo-ready for your January launch video.

---

## 2. Target Merchant (MVP Persona)

- Shopify merchant doing **$5K–$50K/month** in sales.
- Limited technical staff (often solo founder or tiny team).
- Wants **more recovered revenue** but is overwhelmed by complex tools.
- Values **clarity + control** over “black-box” AI.

---

## 3. Core Merchant User Stories (MUST-HAVE)

1. **Install & Connect**
   - As a merchant, I can install Abando from the Shopify App Store and complete setup in **<10 minutes**.
   - As a merchant, I can see a **clear confirmation** that Abando is connected to my store.

2. **Basic Cart Tracking**
   - As a merchant, I can see how many carts were **abandoned** and how many were **recovered via Abando** in a simple dashboard.
   - As a merchant, I can see **revenue recovered** attributed to Abando for a selected time range (e.g., last 7 / 30 days).

3. **Simple Recovery Flow**
   - As a merchant, I can enable a **default recovery flow** (e.g., one follow-up message/email) without editing complex workflows.
   - As a shopper who abandons my cart, I receive **one clear, respectful message** nudging me to complete my purchase.
   - As a merchant, I can **configure the tone** (e.g., “Friendly / Direct / Premium”) for Abando’s messaging.

4. **Transparency & Control**
   - As a merchant, I can **pause Abando** at any time.
   - As a merchant, I can see an **example of the messages** Abando sends on my behalf.
   - As a merchant, I can see what data Abando uses (and doesn’t use) in a **plain-language explanation**.

---

## 4. Nice-to-Have (FOR LATER, NOT MVP)

These are explicitly **out of scope** for the January MVP:

- Multi-channel sequences (SMS + email + on-site widget combos).
- Complex A/B testing UI.
- Deep segmentation (VIP vs new customer vs repeat).
- Multi-store / multi-tenant dashboards across brands.
- Self-serve prompt editing for advanced users.
- Full-blown “AI shopping copilot” with product Q&A chat.

The MVP should support **a single, opinionated default flow** that just works.

---

## 5. Technical MVP Requirements

1. **Shopify Integration**
   - OAuth-based install via Shopify.
   - Webhook handling for:
     - Checkout started / updated
     - Checkout completed
   - Secure storage of merchant + shop metadata.

2. **Event Pipeline (Simplified)**
   - Ingest abandoned cart events into your backend.
   - Mark carts as recovered when orders are completed after a recovery message goes out.
   - Store enough data to attribute “recovered by Abando” vs normal conversions.

3. **Message Engine (v1)**
   - Generate recovery copy using LLM with:
     - Store name
     - Cart contents (product titles, optionally prices)
     - Configured tone
   - Send via **one primary channel** for MVP (choose: email OR on-site message) with a clear link back to the cart.
   - Log each message attempt (time, channel, success/failure).

4. **Merchant Dashboard (MVP UI)**
   - Simple metrics view:
     - Abandoned carts (count)
     - Recovered carts (count)
     - Revenue recovered ($)
     - On/off status
   - Basic configuration:
     - Toggle: Abando ON / OFF
     - Tone selector
   - Clear link to:
     - Privacy / data usage explanation
     - Support email/contact

---

## 6. Non-Goals for January

To protect the timeline, the January MVP **will NOT** attempt:

- Perfectly tuned multi-step behavioral sequences.
- Dynamic discount experimentation (e.g., “try 5%, then 10%”).
- Full mobile app.
- Custom theming of every message per merchant.

These can be **v2+ features** once stable revenue and feedback are coming in.

---

## 7. Success Metrics (January–March)

For the first wave of merchants, the MVP is successful if:

- ✅ Abando is installed and used by **3–5 real stores**.
- ✅ At least **one merchant recovers >$500** in otherwise-lost revenue within 60–90 days.
- ✅ You can show on video:
  - Install flow
  - Dashboard with real numbers
  - Example recovery message
- ✅ System uptime is stable and you can monitor failures via:
  - `/health`
  - `/plan` logging
  - `/metrics/summary` + `ross-metrics`

