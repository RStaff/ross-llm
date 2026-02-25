#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "ERROR: run with bash: bash $0"
  exit 1
fi

echo "=============================="
echo "02 — STAGE SAFE ONLY"
echo "=============================="

git rev-parse --show-toplevel >/dev/null
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
echo "Repo: $ROOT"
echo

echo "==> Resetting staging area (keeps working tree edits)..."
git reset

echo "==> Stage tracked edits (safe)..."
TRACKED_SAFE=(
  ".dvc/config"
  ".gitignore"
  "Makefile"
  "apps/gateway/main.py"
  "apps/orchestrator/main.py"
  "docker-compose.yml"
  "requirements.txt"
)

for p in "${TRACKED_SAFE[@]}"; do
  [[ -e "$p" ]] && git add "$p" || true
done

echo
echo "==> Stage NEW code/config (safe)..."
SAFE_NEW=(
  ".dockerignore"
  "apps/__init__.py"
  "apps/gateway/requirements.txt"
  "apps/orchestrator/__init__.py"
  "apps/orchestrator/embeddings_hf.py"
  "apps/orchestrator/execution_log.py"
  "apps/orchestrator/llm.py"
  "apps/orchestrator/metrics.py"
  "apps/orchestrator/parallel_debug.py"
  "apps/orchestrator/parallel_utils.py"
  "apps/orchestrator/plan.py"
  "apps/orchestrator/retrieval_parallel.py"
  "apps/orchestrator/routes"
  "apps/orchestrator/state.py"
  "apps/orchestrator/status.py"
  "apps/orchestrator/tasks_decompose.py"
  "apps/orchestrator/tenant_config.py"
  "apps/policy"
  "apps/ui"
  "config"
  "docs"
  "packages"
  "scripts"
)

for p in "${SAFE_NEW[@]}"; do
  [[ -e "$p" ]] && git add "$p" || true
done

echo
echo "==> Explicitly unstage local-only items (just in case)..."
git reset -q -- .env.secrets .env logs _data data memory venv 2>/dev/null || true

echo
echo "==> Staged summary:"
git diff --cached --stat
echo
echo "==> Status:"
git status -sb
