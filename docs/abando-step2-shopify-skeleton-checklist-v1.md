# Abando – Step 2 Checklist  
## Shopify app skeleton & OAuth install flow (Weekend Work Plan)

Source: `docs/abando-mvp-10-step-plan-v1.md` – Step 2  
Owner: Ross Stafford  
Goal: A dev store can install Abando and see a “connected” confirmation screen.

---

## 0. Pre-checks (15–20 min)

- [ ] Confirm you can log into your **Shopify Partner** account.
- [ ] Make sure you have at least **one dev store** ready for testing.
- [ ] Decide where this code lives:
  - [ ] Repo name (e.g., `abando-shopify-app`).
  - [ ] Hosting target for the app backend (Render / other).

---

## 1. Create or open the Shopify app project (30–45 min)

- [ ] From your local projects folder:
  - [ ] Create or open the app repo you’ll use for Abando’s Shopify app.
- [ ] Initialize the app if needed:
  - [ ] Ensure you have a package manager + lockfile (`npm`/`pnpm`/`yarn` or backend equivalent).
  - [ ] Add a minimal README explaining: “This is the Abando Shopify embedded app.”
- [ ] Commit a clean baseline:
  - [ ] `git status` is clean.
  - [ ] First commit reflects the bare skeleton before OAuth work.

---

## 2. Register the app in Shopify Partners (30–45 min)

- [ ] In **Shopify Partners → Apps**, create a new custom/public app for Abando.
- [ ] Set:
  - [ ] App name: “Abando – Cart Recovery” (or similar).
  - [ ] App URL: your backend URL (for now this may be `http://localhost:XXXX` or a tunnel like `ngrok`/`cloudflared`).
  - [ ] Redirect URL(s): OAuth callback endpoint (e.g. `/auth/callback`).
- [ ] Copy and securely store:
  - [ ] API key.
  - [ ] API secret key.
- [ ] Add them to your local `.env` file (do not commit):
  - [ ] `SHOPIFY_API_KEY=...`
  - [ ] `SHOPIFY_API_SECRET=...`
  - [ ] Any other required vars (like `SHOPIFY_SCOPES`).

---

## 3. Implement basic app server and health check (30 min)

- [ ] Add a **minimal HTTP server** if you don’t have one yet:
  - [ ] Root endpoint `/` returns simple JSON or HTML: “Abando Shopify app backend is running.”
- [ ] Add a `/health` endpoint:
  - [ ] Returns `{ "ok": true, "service": "abando-shopify-app" }`.
  - [ ] No auth required.
- [ ] Start the server locally and verify:
  - [ ] `curl http://localhost:PORT/health` responds with `ok: true`.

---

## 4. Wire up Shopify OAuth – request phase (60–90 min)

- [ ] Add an `/auth/start` route that:
  - [ ] Accepts `shop` as a query param (e.g., `?shop=my-store.myshopify.com`).
  - [ ] Validates `shop` looks like a Shopify domain.
  - [ ] Redirects to Shopify’s OAuth authorization URL with:
    - [ ] `client_id` = API key.
    - [ ] `scope` = your configured scopes.
    - [ ] `redirect_uri` = your `/auth/callback` endpoint.
    - [ ] `state` = random nonce to protect against CSRF.
- [ ] Log every `/auth/start` hit to console or a simple log helper:
  - [ ] `shop`, `state`, timestamp.

---

## 5. Wire up Shopify OAuth – callback phase (60–90 min)

- [ ] Add an `/auth/callback` route that:
  - [ ] Receives `code`, `hmac`, `shop`, and `state`.
  - [ ] Validates the `hmac` according to Shopify docs (security check).
  - [ ] Verifies `state` matches what you issued in `/auth/start`.
  - [ ] Exchanges the `code` for an access token using Shopify’s API.
- [ ] On success:
  - [ ] Persist the shop + token:
    - [ ] For MVP, choose either:
      - [ ] A simple DB table (`shops`), or
      - [ ] A secure local store (if DB isn’t wired yet).
  - [ ] Log “Shop connected” with `shop`, timestamp.
- [ ] On failure:
  - [ ] Log the error with enough detail to debug (but no secrets).

---

## 6. Post-install “connected” page (30–45 min)

- [ ] After successful token exchange, redirect the merchant to:
  - [ ] An internal route like `/app/connected` (embedded in Shopify).
- [ ] Build a minimal page:
  - [ ] “✅ Abando is connected to your store.”
  - [ ] Short explanation of what happens next (e.g., “Abando will start monitoring abandoned carts once we finish the pipeline.”).
  - [ ] Simple link/button: “Open Dashboard” (even if it’s a placeholder for now).
- [ ] Confirm this page renders correctly as an **embedded app** inside the Shopify admin.

---

## 7. Dev store install test (60 min)

- [ ] Using your dev store:
  - [ ] Install the app via the app URL.
  - [ ] Walk through the OAuth flow:
    - [ ] Hit `/auth/start` with `?shop=your-dev-store.myshopify.com`.
    - [ ] Approve scopes in Shopify.
    - [ ] Land on your “connected” page.
- [ ] Verify:
  - [ ] The shop and token are stored as expected.
  - [ ] No unhandled errors in logs.
  - [ ] `/health` still returns `ok: true`.

---

## 8. Clean up and commit (15–20 min)

- [ ] Run your formatter / linter (if configured).
- [ ] Confirm `.env` and any secrets are in `.gitignore`.
- [ ] Commit with a clear message:
  - [ ] `feat: add Shopify OAuth install flow skeleton`
- [ ] Push to remote (GitHub, etc.).

---

## 9. Add a short status note for future you (10–15 min)

- [ ] In `docs/abando-step2-shopify-skeleton-checklist-v1.md`, add:
  - [ ] A “Status” section at the bottom describing:
    - [ ] What’s done.
    - [ ] What’s partially done.
    - [ ] What’s blocked.
- [ ] Example:

> **Status (Weekend YYYY-MM-DD):**  
> - Completed: app registration, /auth/start, /auth/callback.  
> - Partially done: connected page UX.  
> - Blocked: deciding final DB for token storage.

---

## 10. Definition of Done for Step 2

Step 2 is **done** when:

- [ ] A dev store can install Abando via Shopify.
- [ ] OAuth completes and stores shop + token.
- [ ] The merchant lands on a clear “Abando is connected” page.
- [ ] You can repeat the process cleanly on another dev store if needed.

