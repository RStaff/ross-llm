#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

LOG_FILE="logs/progress.log"
STAMP="$(date '+%Y-%m-%d %H:%M:%S')"

NOTE="${*:-(no description)}"

echo "[$STAMP] $NOTE" >> "$LOG_FILE"

echo "✅ Logged progress:"
echo "[$STAMP] $NOTE"
echo

# Sanitize NOTE for JSON: no newlines, no double quotes
SAFE_NOTE="${NOTE//$'\n'/ }"
SAFE_NOTE="${SAFE_NOTE//\"/\'}"

ross-raw "I just logged this progress: $SAFE_NOTE. Reply in one short sentence as a coach reinforcing momentum. No therapy, no analysis, just concrete, grounded praise."
