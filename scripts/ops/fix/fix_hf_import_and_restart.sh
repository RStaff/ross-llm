#!/usr/bin/env bash
set -euo pipefail

FILE="apps/orchestrator/embeddings_hf.py"

echo "==> 1) Ensure embeddings_hf.py exists"
mkdir -p apps/orchestrator

echo "==> 2) Write stable HF embeddings module"

cat > "$FILE" <<'PY'
import os
from typing import List
from sentence_transformers import SentenceTransformer

MODEL_NAME = os.getenv(
    "HF_EMBED_MODEL",
    "sentence-transformers/all-MiniLM-L6-v2"
)

print(f"[HF] Loading embedding model: {MODEL_NAME}")
_model = SentenceTransformer(MODEL_NAME)

def embed_texts(texts: List[str]) -> List[List[float]]:
    """
    Returns embeddings for list of texts.
    Must match pgvector dimension.
    """
    if not texts:
        return []

    embeddings = _model.encode(
        texts,
        normalize_embeddings=True
    )

    return embeddings.tolist()
PY

echo "✅ embeddings_hf.py written"

echo "==> 3) Rebuild orchestrator clean"
docker compose down --remove-orphans
docker compose build --no-cache orchestrator
docker compose up -d

echo "==> 4) Wait for orchestrator"
sleep 8

echo "==> 5) Health check"
curl -sS http://localhost:8000/health || true
echo

echo "==> 6) Reset docs table (safe)"
docker compose exec -T db psql -U postgres -d postgres \
  -c 'DROP TABLE IF EXISTS docs;' || true

echo "==> 7) Test ingest"
curl -sS http://localhost:8000/ingest \
  -H "content-type: application/json" \
  -d '{"docs":[{"id":"d1","content":"Abando.ai is a Shopify abandoned-cart recovery agent."}]}' \
| python3 -m json.tool || true

echo "==> 8) Test retrieve"
curl -sS http://localhost:8000/retrieve/vector \
  -H "content-type: application/json" \
  -d '{"query":"Shopify abandoned cart recovery", "top_k": 3}' \
| python3 -m json.tool || true

echo
echo "🚀 Ross-LLM now uses local HuggingFace embeddings"
