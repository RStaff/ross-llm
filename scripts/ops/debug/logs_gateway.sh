#!/usr/bin/env bash
set -euo pipefail

cd ~/projects/ross-llm
echo "📜 Showing last 80 lines of GATEWAY logs..."
docker compose logs gateway --tail=80
