#!/usr/bin/env bash
set -e

echo "==> Fixing HuggingFace dependency conflicts"

REQ="requirements.txt"

# Remove conflicting packages if present
sed -i.bak '/^transformers/d' "$REQ" || true
sed -i.bak '/^sentence-transformers/d' "$REQ" || true

# Add compatible versions
cat >> "$REQ" <<EOF

# --- HF embeddings stack ---
sentence-transformers==2.7.0
transformers>=4.41,<5
torch>=2.1.0
EOF

echo "✅ requirements.txt fixed"

echo "==> Rebuilding containers clean"
docker compose down --remove-orphans
docker compose build --no-cache orchestrator
docker compose up -d

echo "==> Waiting for service"
sleep 5

curl -sS http://localhost:8000/health || true

echo "✅ Done"
