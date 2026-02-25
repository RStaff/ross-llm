#!/usr/bin/env bash
set -euo pipefail
[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash: bash $0"; exit 1; }

git rev-parse --show-toplevel >/dev/null
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=============================="
echo "09 — ADD ROOT fix_* SCRIPTS (robust)"
echo "Repo: $ROOT"
echo "=============================="
echo

mkdir -p scripts/ops/fix

shopt -s nullglob
FIX_FILES=(fix_*.sh)
shopt -u nullglob

if [[ ${#FIX_FILES[@]} -eq 0 ]]; then
  echo "No root fix_*.sh files found."
  exit 0
fi

echo "Found ${#FIX_FILES[@]} root fix scripts:"
printf " - %s\n" "${FIX_FILES[@]}"
echo

for f in "${FIX_FILES[@]}"; do
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    echo "git mv $f -> scripts/ops/fix/"
    git mv "$f" "scripts/ops/fix/$f"
  else
    echo "mv (untracked) $f -> scripts/ops/fix/"
    mv "$f" "scripts/ops/fix/$f"
    git add "scripts/ops/fix/$f"
  fi
done

echo
echo "==> Ensure executable bit..."
chmod +x scripts/ops/fix/*.sh || true

echo
echo "==> Summary:"
git diff --cached --stat
echo
git status -sb
