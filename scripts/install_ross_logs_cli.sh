#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing ross-logs CLI helper..."

mkdir -p "$HOME/bin"

cat > "$HOME/bin/ross-logs" << 'BRF'
#!/usr/bin/env bash
# ross-logs - quick views into StaffordOS execution_log

BASE_URL="${ROSS_ORCH_URL:-http://127.0.0.1:8000}"

case "${1:-latest}" in
  latest)
    LIMIT="${2:-10}"
    echo "📜 Latest $LIMIT log rows:"
    curl -s "$BASE_URL/logs/latest?limit=$LIMIT" | jq .
    ;;

  plan)
    LIMIT="${2:-10}"
    echo "📜 Latest $LIMIT /plan calls:"
    curl -s "$BASE_URL/logs/latest?limit=$LIMIT" \
      | jq '.rows | map(select(.endpoint == "/plan"))'
    ;;

  watch)
    # Poor-man's tail -f for logs
    INTERVAL="${2:-5}"
    echo "👀 Watching logs every $INTERVAL seconds (Ctrl+C to stop)..."
    while true; do
      clear
      echo "⏱  $(date) — latest 5 rows"
      echo "──────────────────────────────"
      curl -s "$BASE_URL/logs/latest?limit=5" \
        | jq '.rows | map({ts, endpoint, status, latency_ms})'
      sleep "$INTERVAL"
    done
    ;;

  *)
    echo "Usage:"
    echo "  ross-logs              # latest 10 rows"
    echo "  ross-logs latest 20    # latest 20 rows"
    echo "  ross-logs plan 10      # latest 10 /plan calls"
    echo "  ross-logs watch 3      # refresh every 3s"
    ;;
esac
BRF

chmod +x "$HOME/bin/ross-logs"

# Ensure ~/bin is on PATH
if [ -f "$HOME/.zshrc" ]; then
  if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
    echo "ℹ Added ~/bin to PATH in .zshrc (open a new terminal to pick it up)."
  fi
fi

echo "✅ ross-logs installed."
echo "   Try: ross-logs"
echo "        ross-logs plan 5"
echo "        ross-logs watch 3"
