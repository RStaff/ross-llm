#!/usr/bin/env bash
set -euo pipefail
./scripts/fix_compose_orchestrator_ports.sh
./scripts/rebuild_and_verify.sh
