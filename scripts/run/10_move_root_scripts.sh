#!/usr/bin/env bash
set -euo pipefail
[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash: bash $0"; exit 1; }

git rev-parse --show-toplevel >/dev/null
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=============================="
echo "10 — MOVE ROOT SCRIPTS INTO scripts/*"
echo "Repo: $ROOT"
echo "=============================="
echo

# Helpers
ensure_dir() { mkdir -p "$1"; }

move_one() {
  local src="$1" dst_dir="$2"
  [[ -e "$src" ]] || return 0
  ensure_dir "$dst_dir"

  # If tracked, use git mv; else mv + git add
  if git ls-files --error-unmatch "$src" >/dev/null 2>&1; then
    echo "git mv $src -> $dst_dir/"
    git mv "$src" "$dst_dir/"
  else
    echo "mv (untracked) $src -> $dst_dir/"
    mv "$src" "$dst_dir/"
    git add "$dst_dir/$(basename "$src")"
  fi
}

chmod_exec_glob() {
  local pattern="$1"
  shopt -s nullglob
  local files=( $pattern )
  shopt -u nullglob
  [[ ${#files[@]} -eq 0 ]] && return 0
  chmod +x "${files[@]}" || true
}

# ----------------------------
# Create destination dirs
# ----------------------------
ensure_dir scripts/ops/setup
ensure_dir scripts/ops/deploy
ensure_dir scripts/ops/debug
ensure_dir scripts/ops/provision
ensure_dir scripts/cli
ensure_dir scripts/test
ensure_dir scripts/ops/fix

echo "==> Moving root scripts..."

# ops/setup
move_one setup_20yr_blueprint.sh        scripts/ops/setup
move_one setup_blueprint_tools.sh       scripts/ops/setup
move_one setup_orch_url_override.sh     scripts/ops/setup

# ops/provision (create tenant/profile scripts)
move_one create_extra_profiles_v1.sh    scripts/ops/provision
move_one create_tenant_walls_v1.sh      scripts/ops/provision
move_one create_tenant_walls_v2.sh      scripts/ops/provision
move_one create_tenant_walls_v3.sh      scripts/ops/provision

# ops/debug (debug/log/smoke/status)
move_one debug_orch_url.sh              scripts/ops/debug
move_one logs_gateway.sh                scripts/ops/debug
move_one smoke_orchestrator.sh          scripts/ops/debug
move_one stack_status.sh                scripts/ops/debug

# ops/deploy
move_one deploy_ross_llm_server.sh      scripts/ops/deploy
move_one docker-compose.override.yml    scripts/ops/deploy
move_one docker-compose.hf.override.yml scripts/ops/deploy

# cli (entrypoints / day-to-day)
move_one start.sh                       scripts/cli
move_one ross.sh                        scripts/cli
move_one ross_day.sh                    scripts/cli
move_one ross_llm_chat.sh               scripts/cli
move_one ross_llm_dev_cycle.sh          scripts/cli
move_one ross_llm_down.sh               scripts/cli
move_one ross_llm_levelup_v1.sh         scripts/cli
move_one ross_llm_up.sh                 scripts/cli

# tests
move_one test_chat_via_gateway.sh        scripts/test
move_one test_ross_llm_chat.sh           scripts/test
move_one tests.jsonl                     scripts/test
move_one wf_index_add.sh                 scripts/test

# env helpers (keep out of root; still code)
move_one load_env.sh                     scripts/cli
move_one set_openai_env.sh               scripts/cli
move_one set_openai_env_runtime.sh       scripts/cli
move_one set_openai_key.sh               scripts/cli

echo
echo "==> Ensure executable bit on moved .sh files..."
chmod_exec_glob "scripts/ops/setup/*.sh"
chmod_exec_glob "scripts/ops/provision/*.sh"
chmod_exec_glob "scripts/ops/debug/*.sh"
chmod_exec_glob "scripts/ops/deploy/*.sh"
chmod_exec_glob "scripts/cli/*.sh"
chmod_exec_glob "scripts/test/*.sh"
chmod_exec_glob "scripts/ops/fix/*.sh"

echo
echo "==> Staging tracked moves (git mv already staged)."
# For tracked moves git mv staged; for mv+git add staged; nothing else needed.

echo
echo "==> Summary:"
git diff --cached --stat || true
echo
git status -sb
