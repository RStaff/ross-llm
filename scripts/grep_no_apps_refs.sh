#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "🔎 Searching for 'apps.orchestrator' in *active* python files (excluding backups)..."
grep -RIn "apps\.orchestrator" apps/orchestrator \
  --exclude="*.bak*" \
  --exclude="*backup*" \
  --exclude="*.auto_backup*" \
  --exclude="main.import_shim_backup" \
  | head -n 80 || true
