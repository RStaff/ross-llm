#!/usr/bin/env bash
set -euo pipefail

echo "📍 Moving to project root: ~/projects/ross-llm"
cd ~/projects/ross-llm

REQ_FILE="apps/orchestrator/requirements.txt"

echo "🔎 Ensuring psycopg is listed in \$REQ_FILE: \$REQ_FILE"
if ! grep -qi 'psycopg' "$REQ_FILE"; then
  echo "➕ Adding psycopg[binary] to \$REQ_FILE"
  printf '\npsycopg[binary]\n' >> "$REQ_FILE"
else
  echo "✅ psycopg already present in \$REQ_FILE"
fi

echo "🔧 Rebuilding orchestrator service…"
docker compose build orchestrator

echo "🚀 Starting all services in detached mode…"
docker compose up -d

echo "✅ Done. Orchestrator rebuilt and stack started."
