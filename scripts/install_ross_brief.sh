#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing ross-brief (Execution Brief CLI)..."

mkdir -p "$HOME/bin"

cat << 'BRF' > "$HOME/bin/ross-brief"
#!/usr/bin/env bash
set -euo pipefail

ORCH_URL="http://127.0.0.1:8000"

if [ "$#" -eq 0 ]; then
  echo "Usage: ross-brief \"Your goal here\""
  exit 1
fi

GOAL="$*"

echo "📑 Ross Execution Brief"
echo "   Goal: $GOAL"
echo "   Orchestrator: $ORCH_URL"
echo

# 1) Call /plan
PLAN="$(
  curl -s -X POST "$ORCH_URL/plan" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg goal "$GOAL" '{goal: $goal, max_subtasks: 6, top_k: 2}')"
)"

OK="$(echo "$PLAN" | jq -r '.ok // empty')"
if [ "$OK" != "true" ]; then
  echo "❌ /plan returned ok!=true or error."
  echo "Raw response:"
  echo "$PLAN"
  exit 1
fi

# 2) Print high-level summary
echo "────────────────────────"
echo "🧠 HIGH-LEVEL SUMMARY"
echo "────────────────────────"
echo "$PLAN" | jq -r '.goal' | sed 's/^/• /'
echo

# 3) Subtasks
echo "────────────────────────"
echo "✅ SUBTASKS"
echo "────────────────────────"
SUBTASKS_COUNT="$(echo "$PLAN" | jq '.subtasks | length')"

if [ "$SUBTASKS_COUNT" -eq 0 ]; then
  echo "(no subtasks returned by planner)"
else
  echo "$PLAN" | jq -r '.subtasks[] | "\(.id). \(.text)"'
fi
echo

# 4) Retrieval context (per subtask/query)
echo "────────────────────────"
echo "📚 CONTEXT SNAPSHOT"
echo "────────────────────────"
R_OK="$(echo "$PLAN" | jq -r '.retrieval.ok // empty' 2>/dev/null || echo "")"

if [ "$R_OK" != "true" ]; then
  echo "(no retrieval context or retrieval.ok != true)"
else
  echo "$PLAN" | jq -r '
    .retrieval.results[]? |
    "▶ " + .query + "\n" +
    ( .documents[0]?.snippet // "  (no doc 1)" | "   - " + . ) + "\n" +
    ( .documents[1]?.snippet // "  (no doc 2)" | "   - " + . ) + "\n"
  '
fi

# 5) Latency info
echo "────────────────────────"
echo "⏱  LATENCY"
echo "────────────────────────"
echo "$PLAN" | jq -r '
  "Plan latency: \(.latency_ms // 0 | tostring) ms" +
  (if .retrieval.total_latency_ms then
     "\nRetrieval latency: \(.retrieval.total_latency_ms) ms"
   else
     ""
   end)
'
BRF

chmod +x "$HOME/bin/ross-brief"

# Ensure ~/bin is on PATH
if [ -f "$HOME/.zshrc" ]; then
  if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
    echo "ℹ Added ~/bin to PATH in .zshrc (open a new terminal to pick it up)."
  fi
fi

echo "✅ ross-brief installed."
echo "   Try: ross-brief \"Ship Abando MVP and set up monitoring\""
