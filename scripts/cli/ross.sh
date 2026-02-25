#!/usr/bin/env bash
set -euo pipefail

# Simple Ross-LLM router wrapper.
# Usage:
#   ./ross.sh "Help me plan my week around the girls and my job search."
# or just:
#   ./ross.sh
#
# If no argument is passed, it will prompt you for a message.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# ---------------------------
# 1) Get the message
# ---------------------------
if [[ $# -gt 0 ]]; then
  MESSAGE="$*"
else
  read -rp "💬 Message: " MESSAGE
fi

if [[ -z "${MESSAGE}" ]]; then
  echo "⚠️ Empty message; nothing to send."
  exit 0
fi

LOWER_MSG="$(printf '%s' "$MESSAGE" | tr '[:upper:]' '[:lower:]')"

PROFILE="general"
REASON="no strong match → general (personal-hq lane)"

# ---------------------------
# 2) Routing rules
# Use the narrowest lane that fits.
# Order matters: first match wins.
# ---------------------------

# ── Legal ops (Whole Foods / Amazon case / docs) ──────────────────────────────
if [[ "$LOWER_MSG" == *"whole foods"* ]] || \
   [[ "$LOWER_MSG" == *"wholefoods"* ]] || \
   [[ "$LOWER_MSG" == *"amazon case"* ]] || \
   [[ "$LOWER_MSG" == *"mediation"* ]] || \
   [[ "$LOWER_MSG" == *"exhibit"* ]] || \
   [[ "$LOWER_MSG" == *"binder"* ]] || \
   [[ "$LOWER_MSG" == *"settlement"* ]] || \
   [[ "$LOWER_MSG" == *"mcad"* ]] || \
   [[ "$LOWER_MSG" == *"legal doc"* ]] || \
   [[ "$LOWER_MSG" == *"legal folder"* ]] || \
   [[ "$LOWER_MSG" == *"wholefoods_legal"* ]]; then

  PROFILE="legal-ops"
  REASON="legal keywords → legal-ops (docs, binders, folders)"

# ── Abando / cart-agent / infra ───────────────────────────────────────────────
elif [[ "$LOWER_MSG" == *"abando"* ]] || \
     [[ "$LOWER_MSG" == *"cart-agent"* ]] || \
     [[ "$LOWER_MSG" == *"cart event"* ]] || \
     [[ "$LOWER_MSG" == *"checkout"* ]] || \
     [[ "$LOWER_MSG" == *"abandoned cart"* ]] || \
     [[ "$LOWER_MSG" == *"shopify"* ]] || \
     [[ "$LOWER_MSG" == *"pay.abando.ai"* ]] || \
     [[ "$LOWER_MSG" == *"render"* ]] || \
     [[ "$LOWER_MSG" == *"vercel"* ]] || \
     [[ "$LOWER_MSG" == *"database_url"* ]] || \
     [[ "$LOWER_MSG" == *"prisma"* ]] || \
     [[ "$LOWER_MSG" == *"webhook"* ]] || \
     [[ "$LOWER_MSG" == *"events table"* ]] || \
     [[ "$LOWER_MSG" == *"ai labeler"* ]] || \
     [[ "$LOWER_MSG" == *"aiLabel"* ]]; then

  PROFILE="abando-dev"
  REASON="Abando / infra / events → abando-dev"

# ── Stafford Media AI brand & marketing ───────────────────────────────────────
elif [[ "$LOWER_MSG" == *"stafford media ai"* ]] || \
     [[ "$LOWER_MSG" == *"stafford media consulting"* ]] || \
     [[ "$LOWER_MSG" == *"smedia"* ]] || \
     [[ "$LOWER_MSG" == *"smedia-marketing"* ]] || \
     [[ "$LOWER_MSG" == *"ethical ai"* ]] || \
     [[ "$LOWER_MSG" == *"ai ethics"* ]] || \
     [[ "$LOWER_MSG" == *"linkedin post"* ]] || \
     [[ "$LOWER_MSG" == *"linkedin arc"* ]] || \
     [[ "$LOWER_MSG" == *"content theme"* ]] || \
     [[ "$LOWER_MSG" == *"newsletter"* ]] || \
     [[ "$LOWER_MSG" == *"google ads"* ]] || \
     [[ "$LOWER_MSG" == *"client campaign"* ]] || \
     [[ "$LOWER_MSG" == *"marketing plan"* ]] || \
     [[ "$LOWER_MSG" == *"funnel"* ]]; then

  PROFILE="smedia-marketing"
  REASON="Stafford Media brand/marketing → smedia-marketing"

# ── NKA / No Kings Athletics ──────────────────────────────────────────────────
elif [[ "$LOWER_MSG" == *"nka"* ]] || \
     [[ "$LOWER_MSG" == *"no kings"* ]] || \
     [[ "$LOWER_MSG" == *"no kings athletics"* ]] || \
     [[ "$LOWER_MSG" == *"no kings day"* ]] || \
     [[ "$LOWER_MSG" == *"merch"* ]] || \
     [[ "$LOWER_MSG" == *"drop"* ]] || \
     [[ "$LOWER_MSG" == *"shield logo"* ]] || \
     [[ "$LOWER_MSG" == *"athletic brand"* ]]; then

  PROFILE="nka-brand"
  REASON="NKA / merch / drops → nka-brand"

# ── Personal-HQ (kids / health / job search / schedule) ───────────────────────
elif [[ "$LOWER_MSG" == *"grace"* ]] || \
     [[ "$LOWER_MSG" == *"maya"* ]] || \
     [[ "$LOWER_MSG" == *"girls"* ]] || \
     [[ "$LOWER_MSG" == *"kids"* ]] || \
     [[ "$LOWER_MSG" == *"daughter"* ]] || \
     [[ "$LOWER_MSG" == *"sleep"* ]] || \
     [[ "$LOWER_MSG" == *"insomnia"* ]] || \
     [[ "$LOWER_MSG" == *"health"* ]] || \
     [[ "$LOWER_MSG" == *"workout"* ]] || \
     [[ "$LOWER_MSG" == *"exercise"* ]] || \
     [[ "$LOWER_MSG" == *"nutrition"* ]] || \
     [[ "$LOWER_MSG" == *"job search"* ]] || \
     [[ "$LOWER_MSG" == *"resume"* ]] || \
     [[ "$LOWER_MSG" == *"cover letter"* ]] || \
     [[ "$LOWER_MSG" == *"interview"* ]] || \
     [[ "$LOWER_MSG" == *"apply to"* ]] || \
     [[ "$LOWER_MSG" == *"schedule my week"* ]] || \
     [[ "$LOWER_MSG" == *"plan my week"* ]] || \
     [[ "$LOWER_MSG" == *"cptsd"* ]] || \
     [[ "$LOWER_MSG" == *"ptsd"* ]] || \
     [[ "$LOWER_MSG" == *"energy"* ]] || \
     [[ "$LOWER_MSG" == *"burnout"* ]]; then

  PROFILE="general"
  REASON="personal / kids / health / job search → general (personal-hq)"

fi

# ---------------------------
# 3) Log routing decision
# ---------------------------
echo "🧠 Ross-LLM router:"
echo "   Message : $MESSAGE"
echo "   Profile : $PROFILE"
echo "   Reason  : $REASON"
echo "────────────────────────────────────────────"
echo

# ---------------------------
# 4) Delegate to ross_llm_chat.sh
# ---------------------------
if [[ ! -x "./ross_llm_chat.sh" ]]; then
  echo "❌ ./ross_llm_chat.sh not found or not executable."
  echo "   Make sure it exists and is chmod +x."
  exit 1
fi

./ross_llm_chat.sh "$MESSAGE" "$PROFILE"
