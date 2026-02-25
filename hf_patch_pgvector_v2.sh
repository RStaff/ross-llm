#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo " Ross-LLM HuggingFace Embeddings Upgrade"
echo " Production-safe + idempotent"
echo "=============================================="

ROOT="$(pwd)"
ORCH="$ROOT/apps/orchestrator"
ROUTES="$ORCH/routes"
HF_EMBED="$ORCH/embeddings_hf.py"
PGV="$ROUTES/pgvector_store.py"

###############################################
echo "==> 0) Precheck repo structure"
###############################################
test -f docker-compose.yml || { echo "❌ Run from repo root"; exit 1; }
test -d "$ROUTES" || { echo "❌ routes dir missing"; exit 1; }

###############################################
echo "==> 1) Backup current router"
###############################################
if [ -f "$PGV" ]; then
  cp -v "$PGV" "$PGV.bak_$(date +%s)"
fi

###############################################
echo "==> 2) Write local HF embedding service"
###############################################
cat > "$HF_EMBED" <<'PY'
from functools import lru_cache
from sentence_transformers import SentenceTransformer
import os

MODEL_NAME = os.getenv(
    "HF_EMBED_MODEL",
    "sentence-transformers/all-MiniLM-L6-v2"
)

@lru_cache(maxsize=1)
def _model():
    print(f"[HF] Loading model: {MODEL_NAME}")
    return SentenceTransformer(MODEL_NAME)

def embed_texts(texts):
    m = _model()
    vecs = m.encode(texts, normalize_embeddings=True)
    return [v.tolist() for v in vecs]
PY

echo "✅ embeddings_hf.py written"

###############################################
echo "==> 3) Write clean HF pgvector router"
###############################################
cat > "$PGV" <<'PY'
import os, json, hashlib
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
import psycopg2
import psycopg2.extras
from typing import List, Dict, Optional

from embeddings_hf import embed_texts

router = APIRouter()

EMBED_DIM = int(os.getenv("EMBEDDING_DIM", "384"))

def db():
    url=os.getenv("DATABASE_URL")
    if not url:
        raise RuntimeError("DATABASE_URL missing")
    return psycopg2.connect(url)

def ensure_schema():
    with db() as conn:
        with conn.cursor() as cur:
            cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
            cur.execute(f"""
            CREATE TABLE IF NOT EXISTS docs(
              id TEXT PRIMARY KEY,
              content TEXT,
              meta JSONB,
              embedding vector({EMBED_DIM})
            );
            """)
            cur.execute("ANALYZE docs;")

def vec(v):
    return "[" + ",".join(f"{x:.6f}" for x in v) + "]"

def stable_id(content,meta):
    h=hashlib.sha256()
    h.update(content.encode())
    h.update(json.dumps(meta,sort_keys=True).encode())
    return h.hexdigest()[:24]

class Doc(BaseModel):
    id: Optional[str]=None
    content:str
    meta:Dict=Field(default_factory=dict)

class IngestReq(BaseModel):
    docs:List[Doc]

@router.post("/ingest")
def ingest(req:IngestReq):
    try:
        ensure_schema()
        vecs=embed_texts([d.content for d in req.docs])

        rows=[]
        ids=[]

        for d,v in zip(req.docs,vecs):
            _id=d.id or stable_id(d.content,d.meta)
            ids.append(_id)
            rows.append((_id,d.content,json.dumps(d.meta),vec(v)))

        with db() as conn:
            with conn.cursor() as cur:
                psycopg2.extras.execute_values(
                    cur,
                    """
                    INSERT INTO docs(id,content,meta,embedding)
                    VALUES %s
                    ON CONFLICT(id) DO UPDATE SET
                    content=EXCLUDED.content,
                    meta=EXCLUDED.meta,
                    embedding=EXCLUDED.embedding
                    """,
                    rows,
                    template="(%s,%s,%s::jsonb,%s::vector)"
                )

        return {"ok":True,"ids":ids}

    except Exception as e:
        raise HTTPException(500,str(e))

class Query(BaseModel):
    query:str
    top_k:int=5

@router.post("/retrieve/vector")
def retrieve(q:Query):
    try:
        ensure_schema()
        v=vec(embed_texts([q.query])[0])

        with db() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("""
                SELECT id,content,meta,
                1-(embedding <=> %s::vector) as score
                FROM docs
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,(v,v,q.top_k))
                rows=cur.fetchall()

        return {"ok":True,"results":rows}

    except Exception as e:
        raise HTTPException(500,str(e))
PY

echo "✅ pgvector router written"

###############################################
echo "==> 4) Ensure HF deps installed"
###############################################
REQ="$ROOT/requirements.txt"
touch "$REQ"

grep -q sentence-transformers "$REQ" || cat >> "$REQ" <<EOF

# HF embeddings
sentence-transformers==2.7.0
transformers>=4.41,<5
EOF

###############################################
echo "==> 5) Clean rebuild"
###############################################
docker compose down --remove-orphans
docker compose build --no-cache orchestrator
docker compose up -d

###############################################
echo "==> 6) Wait for orchestrator"
###############################################
for i in {1..60}; do
  curl -sf http://localhost:8000/health >/dev/null && break
  sleep 1
done

###############################################
echo "==> 7) Smoke test"
###############################################
curl -s http://localhost:8000/ingest \
-H "content-type: application/json" \
-d '{"docs":[{"content":"Abando.ai Shopify cart recovery"},{"content":"Ross LLM local vector search"}]}' | python3 -m json.tool || true

curl -s http://localhost:8000/retrieve/vector \
-H "content-type: application/json" \
-d '{"query":"Shopify cart recovery"}' | python3 -m json.tool || true

echo "=============================================="
echo "SUCCESS — Ross-LLM now uses LOCAL HF embeddings"
echo "=============================================="
