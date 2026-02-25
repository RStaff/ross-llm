#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "ERROR: run with bash: bash $0"
  exit 1
fi

echo "=============================="
echo "03 — GUARD: NO SECRETS / DATA STAGED"
echo "=============================="

git rev-parse --show-toplevel >/dev/null
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

FORBIDDEN_REGEX='(^|/)(\.env(\..*)?$|\.env\.secrets$|logs/|_data/|data/|memory/|venv/|__pycache__/|.*\.pid$|.*\.bak$|_quarantine_.*\/)'

STAGED="$(git diff --cached --name-only || true)"

if [[ -z "${STAGED}" ]]; then
  echo "Nothing staged."
  exit 0
fi

BAD="$(echo "$STAGED" | grep -E "$FORBIDDEN_REGEX" || true)"

if [[ -n "${BAD}" ]]; then
  echo "BLOCKED: forbidden items are staged:"
  echo "$BAD"
  echo
  echo "Fix by unstaging them:"
  echo "  git reset -- <file_or_folder>"
  exit 1
fi

echo "OK: no forbidden staged items detected."
echo
echo "Staged files:"
echo "$STAGED"
