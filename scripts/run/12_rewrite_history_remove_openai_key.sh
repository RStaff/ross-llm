#!/usr/bin/env bash
set -euo pipefail
[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash: bash $0"; exit 1; }

git rev-parse --show-toplevel >/dev/null
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "========================================="
echo "12 — REWRITE HISTORY: REMOVE OPENAI KEYS"
echo "Repo: $ROOT"
echo "========================================="
echo

echo "⚠️  This will rewrite local history."
echo "⚠️  Since push was blocked, origin/main does NOT have this commit."
echo

read -p "Type YES to continue: " CONFIRM
[[ "$CONFIRM" == "YES" ]] || { echo "Aborted."; exit 1; }

echo
echo "==> Removing any sk- style OpenAI keys from entire history..."

git filter-branch --force --index-filter \
'git ls-files -z | xargs -0 sed -i "" -E "s/sk-[A-Za-z0-9]{20,}/REDACTED_OPENAI_KEY/g"' \
--prune-empty --tag-name-filter cat -- --all

echo
echo "==> Cleaning backup refs..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo
echo "==> Done. Verifying..."
if git grep -E "sk-[A-Za-z0-9]{20,}" >/dev/null 2>&1; then
  echo "❌ Key pattern still found."
  exit 1
else
  echo "✅ No key patterns detected in repo history."
fi

echo
echo "Now run:"
echo "  git push --force"
