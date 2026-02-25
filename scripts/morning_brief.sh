#!/usr/bin/env bash
set -euo pipefail

# Always run from repo root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "══════════════════════════════════════"
echo "  StaffordOS Morning Brief (v1.0)"
echo "══════════════════════════════════════"
echo

echo "1) Body + nervous system check (ross-freeze)"
echo "--------------------------------------------"
ross-freeze "It's the start of my day. I'm about to work and want one 2–4 minute body reset and one under-5-minute starter action."
echo

echo "2) Progress reality check (last 10 logs)"
echo "----------------------------------------"
scripts/progress_summary.sh
echo

echo "3) Focus decision (ross-ooda)"
echo "-----------------------------"
ross-ooda "It's the start of my day. Based on my current projects (Abando MVP, StaffordOS, and job search), help me pick one realistic focus for today and the smallest reversible step to start with."
echo

echo "✅ Morning Brief complete."
echo "→ Take the smallest action from the OODA section and start there."
