#!/usr/bin/env bash
set -euo pipefail

cat <<'TXT'
You can add this to your shell config (~/.zshrc or ~/.bashrc):

  alias rblue='cd ~/projects/ross-llm && ./scripts/blueprint_status.sh'

Then just run:

  rblue

…to see your current pillars, profiles, and NOW backlog.
TXT
