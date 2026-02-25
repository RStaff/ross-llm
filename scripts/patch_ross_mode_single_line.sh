#!/usr/bin/env bash
set -euo pipefail

TARGET="$HOME/bin/ross-mode"

if [ ! -f "$TARGET" ]; then
  echo "❌ $TARGET not found. Did we create ross-mode already?" >&2
  exit 1
fi

BACKUP="${TARGET}.bak_$(date +%Y%m%d_%H%M%S)"
cp "$TARGET" "$BACKUP"
echo "📦 Backed up existing ross-mode to $BACKUP"

cat << 'MODE' > "$TARGET"
#!/usr/bin/env bash
set -euo pipefail

MODE="$1"
shift || true
USER_MSG="$*"

case "$MODE" in
  cbt)
    PREFIX="StaffordOS v1.2 CBT Debug Mode: use S/T/E/B/R and offer exactly 2 realistic alternative thoughts. No validation of distortions."
    ;;
  ooda)
    PREFIX="StaffordOS v1.2 OODA Mode: Observe facts, Orient on context and power, Decide A/B/C with pros/cons, Act with the smallest reversible step."
    ;;
  freeze)
    PREFIX="StaffordOS v1.2 Freeze Override: give one 2–4 minute physical regulation step, one micro-action under 5 minutes, and one sentence giving permission to stop after. No analysis or philosophy."
    ;;
  lash)
    PREFIX="StaffordOS v1.2 Lash-Out Containment: acknowledge the surge without validating attack, suggest one physical discharge, enforce a 30-minute delay, then rewrite the message in neutral factual tone."
    ;;
  parts)
    PREFIX="StaffordOS v1.2 Parts Router: identify the active part, say what it is protecting, respond as CEO-Ross with a grounded directive, and apply Freeze or Lash protocol if relevant."
    ;;
  *)
    echo "Unknown mode: $MODE (expected: cbt|ooda|freeze|lash|parts)" >&2
    exit 1
    ;;
esac

ross "${PREFIX} User message: ${USER_MSG}"
MODE

chmod +x "$TARGET"
echo "✅ Rewrote $TARGET with single-line prefixes."
