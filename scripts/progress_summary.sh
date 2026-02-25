#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

LOG_FILE="logs/progress.log"

if [ ! -f "$LOG_FILE" ]; then
  echo "📓 No progress.log yet. Log something with:"
  echo "  scripts/progress_tick.sh \"Did X\""
  exit 0
fi

echo "📓 Last 10 progress entries:"
tail -n 10 "$LOG_FILE"
echo

SNIP="$(tail -n 10 "$LOG_FILE" | tr '\n' ' | ' | sed 's/"/\"/g')"

ross-raw "Here are my recent progress entries (most recent last): $SNIP. In 3 short bullet points, tell me what I'm actually doing well and give one realistic next step for today. No fluff."
