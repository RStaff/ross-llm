#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

ROUTE="apps/orchestrator/routes/pgvector_store.py"
MAIN="apps/orchestrator/main.py"

mkdir -p "apps/orchestrator/routes"

cat > "$ROUTE" <<'PY'
from __future__ import annotations

import os, json, hashlib
from typing import Any, Dict, List, Optional

import psycopg2
import psycopg2.extras
import requests
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter()

EMBED_MODEL = os.getenv("EMBEDDING_MODEL", "text-embedding-3-small")
EMBED_DIM = int(os.getenv("EMBEDDING_DIM", "1536"))

def _db():
    url = os.getenv("DATABASE_URL", "")
    if not url:
        raise RuntimeError("DATABASE_URL is not set")
    return psycopg2.connect(url)

def _ensure_schema():
    with _db() as conn:
        with conn.cursor() as cur:
            cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS docs (
                  id TEXT PRIMARY KEY,
                  content TEXT NOT NULL,
                  meta JSONB NOT NULL DEFAULT '{{}}'::jsonb,
                  embedding vector({EMBED_DIM}) NOT NULL
                );
            """)
            cur.execute("""
                CREATE INDEX IF NOT EXISTS docs_embedding_ivfflat
                ON docs USING ivfflat (embedding vector_cosine_ops)
                WITH (lists = 100);
            """)
            cur.execute("ANALYZE docs;")

def _embed(texts: List[str]) -> List[List[float]]:
    key = os.getenv("OPENAI_API_KEY", "")
    if not key:
        raise RuntimeError("OPENAI_API_KEY is not set")

    r = requests.post(
        "https://api.openai.com/v1/embeddings",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json={"model": EMBED_MODEL, "input": texts},
        timeout=60,
    )
    r.raise_for_status()
    data = r.json()
    vecs = [item["embedding"] for item in data["data"]]
    # basic safety check
    for v in vecs:
        if len(v) != EMBED_DIM:
            raise RuntimeError(f"Embedding dim mismatch: expected {EMBED_DIM}, got {len(v)}")
    return vecs

def _stable_id(content: str, meta: Dict[str, Any]) -> str:
    h = hashlib.sha256()
    h.update(content.encode("utf-8"))
    h.update(b"\n")
    h.update(json.dumps(meta, sort_keys=True).encode("utf-8"))
    return h.hexdigest()[:24]

class IngestDoc(BaseModel):
    id: Optional[str] = None
    content: str
    meta: Dict[str, Any] = Field(default_factory=dict)

class IngestRequest(BaseModel):
    docs: List[IngestDoc]

class IngestResponse(BaseModel):
    ok: bool
    upserted: int
    ids: List[str]

@router.post("/ingest", response_model=IngestResponse)
def ingest(req: IngestRequest) -> IngestResponse:
    try:
        _ensure_schema()
        contents = [d.content for d in req.docs]
        vecs = _embed(contents)

        ids: List[str] = []
        rows = []
        for d, v in zip(req.docs, vecs):
            _id = d.id or _stable_id(d.content, d.meta)
            ids.append(_id)
            rows.append((_id, d.content, json.dumps(d.meta), v))

        with _db() as conn:
            with conn.cursor() as cur:
                psycopg2.extras.execute_values(
                    cur,
                    """
                    INSERT INTO docs (id, content, meta, embedding)
                    VALUES %s
                    ON CONFLICT (id) DO UPDATE
                      SET content=EXCLUDED.content,
                          meta=EXCLUDED.meta,
                          embedding=EXCLUDED.embedding
                    """,
                    rows,
                    template="(%s, %s, %s::jsonb, %s)",
                )

        return IngestResponse(ok=True, upserted=len(ids), ids=ids)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ingest_failed: {e!r}")

class RetrieveRequest(BaseModel):
    query: str
    top_k: int = 6

class RetrievedDoc(BaseModel):
    id: str
    score: float
    content: str
    meta: Dict[str, Any]

class RetrieveResponse(BaseModel):
    ok: bool
    backend: str
    results: List[RetrievedDoc]

@router.post("/retrieve/vector", response_model=RetrieveResponse)
def retrieve_vector(req: RetrieveRequest) -> RetrieveResponse:
    try:
        _ensure_schema()
        qv = _embed([req.query])[0]

        with _db() as conn:
            with conn.cursor() as cur:
                # cosine distance => smaller is better; convert to similarity-ish score
                cur.execute(
                    """
                    SELECT id, content, meta, (1 - (embedding <=> %s::vector)) AS score
                    FROM docs
                    ORDER BY embedding <=> %s::vector
                    LIMIT %s
                    """,
                    (qv, qv, req.top_k),
                )
                rows = cur.fetchall()

        out: List[RetrievedDoc] = []
        for _id, content, meta, score in rows:
            out.append(RetrievedDoc(id=_id, content=content, meta=meta or {}, score=float(score)))

        return RetrieveResponse(ok=True, backend="pgvector", results=out)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"retrieve_failed: {e!r}")
PY

# Patch main.py to include this router (idempotent-ish)
python3 - <<'PY'
from pathlib import Path
import re

main = Path("apps/orchestrator/main.py")
txt = main.read_text()

if "pgvector_store" in txt:
    print("ℹ️ main.py already references pgvector_store; skipping patch.")
    raise SystemExit(0)

# Add import near other route imports if possible
insert_pat = r"(from\s+routes\.memory\s+import\s+router\s+as\s+memory_router\s*\n)"
m = re.search(insert_pat, txt)
if not m:
    # fallback: just append import near top-ish
    txt = "from routes.pgvector_store import router as pgvector_router\n" + txt
else:
    txt = re.sub(insert_pat, m.group(1) + "from routes.pgvector_store import router as pgvector_router\n", txt, count=1)

# Include router near where memory router is included, else append near app init
if "include_router(memory_router" in txt and "include_router(pgvector_router" not in txt:
    txt = txt.replace("app.include_router(memory_router)", "app.include_router(memory_router)\napp.include_router(pgvector_router)")
elif "include_router(pgvector_router" not in txt:
    # very safe fallback append
    txt += "\n\n# pgvector router\ntry:\n    app.include_router(pgvector_router)\nexcept Exception as _e:\n    print(f\"Warning: failed to load pgvector_store router: {_e!r}\")\n"

main.write_text(txt)
print("✅ Patched main.py to include pgvector_store router")
PY

echo "✅ Added $ROUTE and patched $MAIN"

echo "✅ Compile check:"
python3 -m py_compile "$ROUTE" "apps/orchestrator/main.py"
