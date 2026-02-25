from __future__ import annotations

from typing import Any, Dict, List, Optional
import os
import time
import hashlib

import psycopg
from psycopg.rows import dict_row
from pgvector.psycopg import register_vector

from fastapi import APIRouter
from pydantic import BaseModel, Field

# Optional (but already in your requirements.txt)
from sentence_transformers import SentenceTransformer


router = APIRouter()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@db:5432/rossllm")
EMBED_MODEL_NAME = os.getenv("EMBED_MODEL_NAME", "sentence-transformers/all-MiniLM-L6-v2")
EMBED_MODEL_TAG  = os.getenv("EMBED_MODEL_TAG", "all-MiniLM-L6-v2")  # stored in ross.chunk_embeddings.model


def _connect():
    conn = psycopg.connect(DATABASE_URL)
    register_vector(conn)
    return conn


_model: Optional[SentenceTransformer] = None

def _get_model() -> SentenceTransformer:
    global _model
    if _model is None:
        # first call will download weights if not present
        _model = SentenceTransformer(EMBED_MODEL_NAME)
    return _model


def _embed_384(text: str) -> List[float]:
    m = _get_model()
    vec = m.encode([text], normalize_embeddings=True)[0]
    # vec is numpy; convert to plain list[float] for psycopg/pgvector adapter
    return [float(x) for x in vec]


class MultiRetrieveRequest(BaseModel):
    queries: List[str] = Field(..., description="Natural language search or retrieval queries.")
    top_k: int = Field(6, ge=1, le=50)


class RetrieveItem(BaseModel):
    id: int
    document_id: int
    snippet: str
    distance: Optional[float] = None


class MultiRetrieveResponse(BaseModel):
    ok: bool
    results: List[Dict[str, Any]]
    backend: str


async def _pgvector_retrieve(query: str, top_k: int) -> List[Dict[str, Any]]:
    qvec = _embed_384(query)

    sql = """
    SELECT
      c.id,
      c.document_id,
      left(c.content, 300) AS snippet,
      (e.embedding_384 <=> %(qvec)s) AS distance
    FROM ross.chunk_embeddings e
    JOIN ross.document_chunks c ON c.id = e.chunk_id
    WHERE e.model = %(model)s
    ORDER BY e.embedding_384 <=> %(qvec)s
    LIMIT %(k)s;
    """

    with _connect() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(sql, {"qvec": qvec, "model": EMBED_MODEL_TAG, "k": top_k})
        rows = cur.fetchall()
    return [dict(r) for r in rows]


async def _keyword_fallback(query: str, top_k: int) -> List[Dict[str, Any]]:
    # Simple fallback if embeddings are empty
    sql = """
    SELECT
      id,
      document_id,
      left(content, 300) AS snippet
    FROM ross.document_chunks
    WHERE content ILIKE %(pat)s
    ORDER BY id DESC
    LIMIT %(k)s;
    """
    with _connect() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(sql, {"pat": f"%{query}%", "k": top_k})
        rows = cur.fetchall()
    out = []
    for r in rows:
        d = dict(r)
        d["distance"] = None
        out.append(d)
    return out


@router.post("/retrieve/multi", response_model=MultiRetrieveResponse)
async def multi_retrieve(payload: MultiRetrieveRequest) -> MultiRetrieveResponse:
    started = time.time()

    # If no embeddings exist, do fallback
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM ross.chunk_embeddings WHERE model=%s", (EMBED_MODEL_TAG,))
        (n,) = cur.fetchone()

    results = []
    backend = "pgvector" if n > 0 else "keyword_fallback"

    for q in payload.queries:
        try:
            if n > 0:
                docs = await _pgvector_retrieve(q, payload.top_k)
            else:
                docs = await _keyword_fallback(q, payload.top_k)
            results.append({"query": q, "docs": docs})
        except Exception as e:
            results.append({"query": q, "docs": [{"id": -1, "document_id": -1, "snippet": f"retrieval error: {e}", "distance": None}]})

    return MultiRetrieveResponse(
        ok=True,
        results=results,
        backend=backend,
    )
