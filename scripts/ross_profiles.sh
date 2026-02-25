#!/usr/bin/env bash
set -euo pipefail

# Run from repo root even if invoked elsewhere
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ross-raw "List all current Ross-LLM profiles and for each, give: (1) its name, (2) what it is optimized for, and (3) when I should use it instead of general. Answer in a short bullet list."
