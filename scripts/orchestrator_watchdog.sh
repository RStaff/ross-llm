#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/projects/ross-llm"
HEALTH_URL="http://127.0.0.1:8000/health"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

echo "🫡 StaffordOS Orchestrator Watchdog"
echo "   Monitoring $HEALTH_URL"
echo "   Press Ctrl+C to stop."
echo

while true; do
  # Is anything listening on 8000?
  PIDS="$(lsof -tn -iTCP:8000 -sTCP:LISTEN 2>/dev/null || true)"

  if [[ -z "$PIDS" ]]; then
    echo "$(date) — Orchestrator DOWN (no process on 8000). Restarting..." | tee -a "$LOG_DIR/watchdog.log"
    (
      cd "$ROOT"
      ./staffordos_restart.sh >> "$LOG_DIR/watchdog.log" 2>&1
    )
    sleep 10
    continue
  fi

  # Check health endpoint
  STATUS="$(curl -s -m 3 "$HEALTH_URL" || true)"
  if [[ "$STATUS" != *'"ok":true'* ]]; then
    echo "$(date) — Orchestrator UNHEALTHY (health: $STATUS). Restarting..." | tee -a "$LOG_DIR/watchdog.log"
    kill $PIDS 2>/dev/null || true
    (
      cd "$ROOT"
      ./staffordos_restart.sh >> "$LOG_DIR/watchdog.log" 2>&1
    )
    sleep 10
  else
    # Everything fine
    sleep 30
  fi
done
