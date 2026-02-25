#!/usr/bin/env bash
set -euo pipefail
cd ~/projects/ross-llm

# Ensure db is up
docker compose up -d db >/dev/null

# Run a python ingester on the host (uses your local python + installs deps if missing)
python3 - <<'PY'
import os, hashlib, textwrap, time
import psycopg
from pgvector.psycopg import register_vector
from sentence_transformers import SentenceTransformer

DB = os.getenv("DEMO_DB", "postgresql://postgres:postgres@localhost:5432/rossllm")
MODEL_NAME = os.getenv("EMBED_MODEL_NAME", "sentence-transformers/all-MiniLM-L6-v2")
MODEL_TAG  = os.getenv("EMBED_MODEL_TAG", "all-MiniLM-L6-v2")

doc_text = """Ross-LLM demo document.

This is a demo ingestion to prove Path B:
- insert into ross.documents
- chunk into ross.document_chunks
- embed into ross.chunk_embeddings (vector(384))

If you see retrieval results after this, pgvector wiring is working.
"""

def sha(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()

def chunk(text: str, max_chars: int = 700):
    # simple deterministic chunking
    text = text.strip()
    out = []
    while text:
        out.append(text[:max_chars])
        text = text[max_chars:]
    return out

print("Connecting:", DB)
conn = psycopg.connect(DB)
register_vector(conn)
conn.autocommit = True

m = SentenceTransformer(MODEL_NAME)

with conn.cursor() as cur:
    # insert document
    content_hash = sha(doc_text)
    cur.execute("""
      INSERT INTO ross.documents (source, source_id, title, url, content, content_hash, metadata)
      VALUES ('demo', NULL, 'Path B Demo', NULL, %s, %s, '{}'::jsonb)
      RETURNING id;
    """, (doc_text, content_hash))
    doc_id = cur.fetchone()[0]
    print("Inserted ross.documents id:", doc_id)

    # chunks + embeddings
    chunks = chunk(doc_text)
    for i, ch in enumerate(chunks):
        ch_hash = sha(ch)
        cur.execute("""
          INSERT INTO ross.document_chunks (document_id, chunk_index, content, content_hash)
          VALUES (%s, %s, %s, %s)
          RETURNING id;
        """, (doc_id, i, ch, ch_hash))
        chunk_id = cur.fetchone()[0]

        vec = m.encode([ch], normalize_embeddings=True)[0]
        vec = [float(x) for x in vec]

        cur.execute("""
          INSERT INTO ross.chunk_embeddings (chunk_id, model, embedding_384)
          VALUES (%s, %s, %s);
        """, (chunk_id, MODEL_TAG, vec))

    print(f"Inserted chunks: {len(chunks)} and embeddings: {len(chunks)}")

print("Done.")
PY

echo
echo "Row counts now:"
docker compose exec -T db psql -U postgres -d rossllm -c "
SELECT
  (SELECT count(*) FROM ross.documents) AS documents,
  (SELECT count(*) FROM ross.document_chunks) AS chunks,
  (SELECT count(*) FROM ross.chunk_embeddings) AS chunk_embeddings,
  (SELECT count(*) FROM ross.embedding_jobs) AS embedding_jobs;
"
