#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "ERROR: run with bash: bash $0"
  exit 1
fi

echo "=============================="
echo "01 — CLEAN + QUARANTINE + IGNORE"
echo "=============================="

git rev-parse --show-toplevel >/dev/null
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
echo "Repo: $ROOT"
echo

STAMP="$(date +%Y%m%d_%H%M%S)"
QUAR="_quarantine_$STAMP"
mkdir -p "$QUAR"

echo "==> Quarantining runtime pids..."
for f in .orchestrator.pid .ui.pid; do
  [[ -f "$f" ]] && mv "$f" "$QUAR/" || true
done

echo "==> Quarantining backups..."
find . -type f \( -name "*.bak" -o -name "*.auto_backup" -o -name "*.import_shim_backup" -o -name "*.persona_bak" \) \
  -not -path "./.git/*" -print0 | while IFS= read -r -d '' f; do
    mkdir -p "$QUAR/$(dirname "$f")"
    mv "$f" "$QUAR/$f"
  done

echo "==> Quarantining temp eval CSVs (repo root only)..."
shopt -s nullglob
for f in eval_tmp.csv eval_run_*.csv; do
  [[ -f "$f" ]] && mv "$f" "$QUAR/" || true
done
shopt -u nullglob

echo "Quarantine folder created: $QUAR"
echo

echo "==> Hardening .gitignore ..."
touch .gitignore

append_if_missing () {
  local line="$1"
  grep -qxF "$line" .gitignore || echo "$line" >> .gitignore
}

append_if_missing ""
append_if_missing "# --- ross-llm local-only ---"
append_if_missing ".env.secrets"
append_if_missing ".env"
append_if_missing "*.pid"
append_if_missing "logs/"
append_if_missing "_data/"
append_if_missing "data/"
append_if_missing "memory/"
append_if_missing "venv/"
append_if_missing "__pycache__/"
append_if_missing "*.pyc"
append_if_missing "*.bak"
append_if_missing "*_backup*"
append_if_missing "_quarantine_*/"
append_if_missing ""
echo "Done."
echo

echo "==> Ensuring local-only files are not staged..."
git reset -q -- .env.secrets .env 2>/dev/null || true
git reset -q -- logs _data data memory venv 2>/dev/null || true
echo "OK."
echo

echo "==> Status:"
git status -sb
