#!/usr/bin/env bash
set -euo pipefail
[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash: bash $0"; exit 1; }

git rev-parse --show-toplevel >/dev/null
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=============================="
echo "06 — STAGE ARCH CORE"
echo "Repo: $ROOT"
echo "=============================="
echo

echo "==> Reset staging area..."
git reset

echo "==> Stage root reproducibility files..."
ROOT_FILES=(
  ".dvc/config"
  ".gitignore"
  ".dockerignore"
  "Makefile"
  "docker-compose.yml"
  "docker-compose.override.yml"
  "docker-compose.hf.override.yml"
  "docker-compose.hf.override.yml"
  "requirements.txt"
)

for f in "${ROOT_FILES[@]}"; do
  [[ -e "$f" ]] && git add "$f" || true
done

# If you have requirements.txt variants, include them
shopt -s nullglob
for f in requirements*.txt; do
  [[ -f "$f" ]] && git add "$f"
done
shopt -u nullglob

echo
echo "==> Stage apps (gateway + orchestrator + policy + ui)..."
for d in apps/gateway apps/orchestrator apps/policy apps/ui; do
  [[ -d "$d" ]] && git add "$d" || true
done

# Optional: keep orchestrator profiles OUT by default (often local)
if [[ -d "apps/orchestrator/profiles" ]]; then
  echo "==> Keeping apps/orchestrator/profiles OUT of staging (default)..."
  git reset -q -- apps/orchestrator/profiles 2>/dev/null || true
fi

echo
echo "==> Stage packages/ scripts/ config/ docs/ (source-of-truth only)..."
for d in packages scripts config docs; do
  [[ -d "$d" ]] && git add "$d" || true
done

echo
echo "==> Explicitly unstage local-only items..."
git reset -q -- .env .env.secrets logs _data data memory venv 2>/dev/null || true

echo
echo "==> Summary:"
git diff --cached --stat
echo
git status -sb
