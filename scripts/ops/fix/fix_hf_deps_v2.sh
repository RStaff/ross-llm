#!/usr/bin/env bash
set -euo pipefail

echo "==> Fixing HuggingFace dependency conflicts (idempotent)"

REQ="requirements.txt"

# 1) Remove conflicting pins (and any previous HF block)
# macOS sed supports -i.bak; Linux sed also ok with -i.bak on most distros
sed -i.bak '/^transformers[<=>]/d' "$REQ" || true
sed -i.bak '/^sentence-transformers[<=>]/d' "$REQ" || true
sed -i.bak '/^torch[<=>]/d' "$REQ" || true
sed -i.bak '/^# --- HF embeddings stack ---$/,/^$/d' "$REQ" || true

# 2) Add a clean, compatible HF stack (let sentence-transformers choose torch)
cat >> "$REQ" <<'EOF'

# --- HF embeddings stack ---
sentence-transformers==2.7.0
transformers>=4.41,<5
EOF

echo "✅ requirements.txt updated (no duplicate blocks)"

echo "==> Rebuilding containers clean"
docker compose down --remove-orphans

# Force a clean orchestrator rebuild (this is where deps matter)
docker compose build --no-cache orchestrator

docker compose up -d

echo "==> Waiting for /health"
for i in {1..40}; do
  if curl -sf http://localhost:8000/health >/dev/null; then
    echo "✅ orchestrator is healthy"
    curl -sS http://localhost:8000/health; echo
    exit 0
  fi
  sleep 0.25
done

echo "❌ orchestrator did not become healthy. Showing last 120 log lines:"
docker compose logs --tail=120 orchestrator || true
exit 1
