#!/usr/bin/env bash
set -euo pipefail

cd ~/projects/ross-llm

cat > docker-compose.override.yml <<'YML'
services:
  gateway:
    environment:
      - ORCH_URL=http://orchestrator:8000
YML

echo "✅ docker-compose.override.yml written with:"
echo "    gateway → ORCH_URL=http://orchestrator:8000"
echo
echo "Next: run ./ross_llm_dev_cycle.sh to restart and test."
