#!/usr/bin/env bash
set -euo pipefail
[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash: bash $0"; exit 1; }

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=============================================="
echo "12 — ROOTFIX: REMOVE SECRETS FROM GIT HISTORY"
echo "Repo: $ROOT"
echo "=============================================="
echo

echo "==> Preflight: show current blocked commit info (if any)"
git log -1 --oneline || true
echo

# Ensure clean working tree (filter-repo wants this)
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "❌ Working tree or index not clean."
  echo "   Commit/stash your changes first, then re-run."
  exit 1
fi

# Install git-filter-repo if missing (pip user install)
if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "==> git-filter-repo not found. Installing with pip (user install)..."
  if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ python3 not found. Install Python 3, then re-run."
    exit 1
  fi
  python3 -m pip install --user --upgrade git-filter-repo
  export PATH="$HOME/Library/Python/3.*/bin:$HOME/.local/bin:$PATH"
fi

if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "❌ git-filter-repo still not found on PATH after install."
  echo "Try: python3 -m site --user-base"
  exit 1
fi

echo
echo "⚠️  This will rewrite history to remove secrets."
echo "⚠️  You will force-push afterwards."
read -p "Type YES to continue: " CONFIRM
[[ "$CONFIRM" == "YES" ]] || { echo "Aborted."; exit 1; }

echo
echo "==> Rewriting history: replace sk-... patterns anywhere with REDACTED_OPENAI_KEY"
git filter-repo --force \
  --replace-text <(cat <<'TXT'
regex:sk-[A-Za-z0-9]{20,}==>REDACTED_OPENAI_KEY
TXT
)

echo
echo "==> Verification: scanning repo for sk- pattern (should be none)"
if git grep -nE 'sk-[A-Za-z0-9]{20,}' >/dev/null 2>&1; then
  echo "❌ Still found an sk- pattern somewhere."
  git grep -nE 'sk-[A-Za-z0-9]{20,}' || true
  exit 1
fi

echo "✅ History rewritten and no sk- patterns detected."
echo
echo "Next:"
echo "  git push --force --all"
echo "  git push --force --tags"
