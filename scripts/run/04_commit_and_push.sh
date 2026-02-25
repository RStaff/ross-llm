#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "ERROR: run with bash: bash $0"
  exit 1
fi

MSG="${1:-Clean base: stabilize ross-llm architecture}"

git rev-parse --show-toplevel >/dev/null
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=============================="
echo "04 — COMMIT + PUSH"
echo "=============================="
echo "Message: $MSG"
echo

# Re-run guard before commit
bash scripts/run/03_guard_no_secrets.sh

echo
echo "==> Commit..."
git commit -m "$MSG"

echo "==> Push..."
git push

echo "Done."
