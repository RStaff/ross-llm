#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "══════════════════════════════════════"
echo "  StaffordOS Evening Brief (v1.0)"
echo "══════════════════════════════════════"
echo

echo "1) Reality check (last 10 progress entries)"
echo "-------------------------------------------"
scripts/progress_summary.sh
echo

echo "2) Gentle shutdown (ross-freeze)"
echo "--------------------------------"
ross-freeze "It's the end of my workday. Give me one 2–4 minute physical reset and one tiny action to close the day (like writing tomorrow's top task), plus one sentence giving me explicit permission to be done."
echo

echo "✅ Evening Brief complete."
echo "→ You are allowed to be off-duty now."
