#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$HOME/projects/ross-llm}"
cd "$ROOT"

echo "🧭 Ross-LLM Blueprint Status"
echo "Root: $ROOT"
echo

#########################
# Pillar headings
#########################
echo "=== Pillars ==="
for f in docs/blueprint/core_os/01_core_os_overview.md \
         docs/blueprint/shopify_agent/02_shopify_agent_overview.md \
         docs/blueprint/devops_agent/03_devops_agent_overview.md \
         docs/blueprint/life_archive/04_life_archive_overview.md \
         docs/blueprint/swarm/05_swarm_overview.md
do
  if [ -f "$f" ]; then
    title="$(grep -m1 '^# ' "$f" | sed 's/^# //')"
    printf " • %s  (%s)\n" "$title" "$(basename "$f")"
  fi
done
echo

#########################
# Profiles (if registry exists)
#########################
if [ -f docs/blueprint/status/profiles_registry.md ]; then
  echo "=== Profiles (from profiles_registry.md) ==="
  # Show just the table body, skip header lines
  awk 'NR>4 {print}' docs/blueprint/status/profiles_registry.md
  echo
else
  echo "ℹ️ No profiles_registry.md yet. Run:"
  echo "   ./scripts/snapshot_profiles.sh"
  echo
fi

#########################
# Backlog NOW section
#########################
BACKLOG="docs/blueprint/status/roadmap_backlog.md"
if [ -f "$BACKLOG" ]; then
  echo "=== NOW Backlog ==="
  awk '
    /## NOW/ {flag=1; next}
    /## NEXT/ {flag=0}
    flag {print}
  ' "$BACKLOG"
  echo
else
  echo "ℹ️ No roadmap_backlog.md found."
  echo
fi

echo "Tip: Use:"
echo "  ./scripts/snapshot_profiles.sh   # refresh profile list"
echo "  ./scripts/blueprint_status.sh    # view this dashboard"
