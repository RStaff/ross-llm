#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "🧠 Ross-LLM Daily Driver"
echo "   (auto-start + profile switcher)"
echo

# --- 1) Ensure stack is up and healthy ---
check_health() {
  local ok=0

  if ! curl -s http://localhost:8000/health >/dev/null 2>&1; then
    ok=1
  fi

  if ! curl -s http://localhost:8000/health >/dev/null 2>&1; then
    ok=1
  fi

  return $ok
}

if ! check_health; then
  echo "🐳 Stack not healthy. Running ./start.sh …"
  ./start.sh
else
  echo "✅ Stack already healthy."
fi

echo
echo "📂 Available profile lanes (tenant walls v3):"
echo "  personal:"
echo "    - general           → life / kids / job search / health"
echo
echo "  Stafford Media / business:"
echo "    - smedia-marketing  → Stafford Media AI content + marketing"
echo
echo "  Abando:"
echo "    - abando-dev        → infra, deployments, env vars, CI"
echo
echo "  NKA:"
echo "    - nka-brand         → merch, brand & drops planning"
echo
echo "  Legal operations:"
echo "    - legal-ops         → document organization, timelines (no advice)"
echo

echo "Type a profile name from above, or 'q' to quit."
echo

while true; do
  read -rp "🔧 Profile (general / smedia-marketing / abando-dev / nka-brand / legal-ops, q=quit): " PROFILE

  if [[ -z "${PROFILE}" ]]; then
    echo "⚠️ Please enter a profile name."
    continue
  fi

  if [[ "${PROFILE}" == "q" || "${PROFILE}" == "quit" ]]; then
    echo "👋 Exiting Ross-LLM daily driver."
    exit 0
  fi

  case "${PROFILE}" in
    general|smedia-marketing|abando-dev|nka-brand|legal-ops)
      ;;
    *)
      echo "❌ Unknown profile: ${PROFILE}"
      echo "   Use one of: general, smedia-marketing, abando-dev, nka-brand, legal-ops"
      continue
      ;;
  esac

  read -rp "💬 Message: " MESSAGE
  if [[ -z "${MESSAGE}" ]]; then
    echo "⚠️ Empty message; try again."
    continue
  fi

  echo
  echo "📤 Sending to Ross-LLM (profile=${PROFILE})…"
  echo "────────────────────────────────────────────"
  ./ross_llm_chat.sh "${MESSAGE}" "${PROFILE}"
  echo "────────────────────────────────────────────"
  echo
done
