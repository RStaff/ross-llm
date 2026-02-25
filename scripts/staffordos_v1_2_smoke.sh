#!/usr/bin/env bash
set -euo pipefail

echo "🩺 StaffordOS v1.2 – Full Smoke Test"
echo "Repo: $(pwd)"
echo "Time: $(date)"
echo "────────────────────────────────"

# 0) Ensure orchestrator is up
echo
echo "0) Restart StaffordOS (ross-down / ross-up)"
ross-down || echo "🛈 Already down (that's fine)"
ross-up

echo
echo "1) Basic /health and deep health"
echo "────────────────────────────────"
echo "- ross-health:"
ross-health || echo "⚠️ ross-health failed"

echo
echo "- ross-deep-health:"
ross-deep-health || echo "⚠️ ross-deep-health failed"

echo
echo "2) Exercise all five StaffordOS v1.2 modes"
echo "────────────────────────────────"

echo
echo "2a) ross-cbt"
ross-cbt "I'm avoiding finishing the Abando MVP because I'm scared of failing and feel totally frozen."

echo
echo "2b) ross-ooda"
ross-ooda "I'm deciding whether to apply to a new job while trying to launch Abando; help me pick a smallest reversible step."

echo
echo "2c) ross-freeze"
ross-freeze "I keep staring at my screen instead of doing the next small task today."

echo
echo "2d) ross-lash"
ross-lash "I want to send a pissed-off message about being forced to regenerate API keys again."

echo
echo "2e) ross-parts"
ross-parts "I'm torn between just being a dad and going all-in on being a founder. Who is talking inside me right now?"

echo
echo "3) Latest execution logs (if wired for /plan + /chat)"
echo "────────────────────────────────"
curl -s "http://127.0.0.1:8000/logs/latest?limit=10" | jq '.' || echo "⚠️ /logs/latest failed or jq missing"

echo
echo "4) Metrics summary for last 24h"
echo "────────────────────────────────"
ross-metrics 1440 || echo "⚠️ ross-metrics failed"

echo
echo "✅ StaffordOS v1.2 smoke test finished."
