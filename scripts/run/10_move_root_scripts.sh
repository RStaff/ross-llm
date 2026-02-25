#!/usr/bin/env bash
set -euo pipefail
[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash: bash $0"; exit 1; }

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "10 — MOVE ROOT SCRIPTS INTO scripts/*"
echo "Repo: $ROOT"
echo

mkdir -p \
  scripts/cli \
  scripts/ops/{fix,deploy,debug,setup,provision} \
  scripts/test

move_if_exists () {
  local src="$1" dst="$2"
  [[ -e "$src" ]] || return 0
  [[ "$src" == "$dst" ]] && return 0
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" ]]; then
    echo "SKIP exists: $dst"
    return 0
  fi
  mv "$src" "$dst"
  echo "MOVED: $src -> $dst"
}

# YAML / compose
move_if_exists docker-compose.override.yml scripts/ops/deploy/docker-compose.override.yml
move_if_exists docker-compose.hf.override.yml scripts/ops/deploy/docker-compose.hf.override.yml

# CLI / convenience
for f in ross.sh ross_day.sh ross_llm_chat.sh ross_llm_dev_cycle.sh ross_llm_down.sh ross_llm_levelup_v1.sh ross_llm_up.sh start.sh load_env.sh set_openai_env.sh set_openai_env_runtime.sh set_openai_key.sh set_openai_env.sh; do
  move_if_exists "$f" "scripts/cli/$f"
done

# Debug
for f in debug_orch_url.sh logs_gateway.sh smoke_orchestrator.sh stack_status.sh; do
  move_if_exists "$f" "scripts/ops/debug/$f"
done

# Deploy
move_if_exists deploy_ross_llm_server.sh scripts/ops/deploy/deploy_ross_llm_server.sh

# Provision
for f in create_extra_profiles_v1.sh create_tenant_walls_v1.sh create_tenant_walls_v2.sh create_tenant_walls_v3.sh; do
  move_if_exists "$f" "scripts/ops/provision/$f"
done

# Setup / bootstrap
for f in setup_20yr_blueprint.sh setup_blueprint_tools.sh setup_orch_url_override.sh install_staffordos_core.sh staffordos_boot.sh staffordos_boot_fix.sh staffordos_restart.sh; do
  move_if_exists "$f" "scripts/ops/setup/$f"
done

# Fix scripts
for f in fix_hf_deps.sh fix_hf_deps_v2.sh fix_hf_import_and_restart.sh fix_jellyfin_compose.sh fix_orchestrator_psycopg.sh force_hf_embeddings.sh force_hf_embeddings_v2.sh hf_apply_patch_and_reset_v2.sh hf_fix_dim_and_reset.sh hf_patch_dynamic.sh hf_patch_pgvector_v2.sh patch_pgvector_to_hf.sh patch_pgvector_to_hf.sh step0_fix_apps_import.sh step0_fix_orchestrator_startup.sh step0_fix_orchestrator_startup_v2.sh step1_add_ventures_api.sh step_add_jellyfin.sh switch_to_hf_embeddings.sh switch_to_hf_embeddings_v2.sh; do
  move_if_exists "$f" "scripts/ops/fix/$f"
done

# Tests
move_if_exists test_chat_via_gateway.sh scripts/test/test_chat_via_gateway.sh
move_if_exists test_ross_llm_chat.sh scripts/test/test_ross_llm_chat.sh
move_if_exists wf_index_add.sh scripts/test/wf_index_add.sh
move_if_exists tests.jsonl scripts/test/tests.jsonl

# Make sure shell scripts are executable
echo
echo "==> chmod +x scripts/**/*.sh"
find scripts -type f -name "*.sh" -print0 | xargs -0 chmod +x || true

echo
echo "==> Status (short):"
git status --porcelain=v1
