BEGIN;

CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS ross;

CREATE TABLE IF NOT EXISTS ross.documents (
  id           BIGSERIAL PRIMARY KEY,
  source       TEXT NOT NULL,
  source_id    TEXT,
  title        TEXT,
  url          TEXT,
  content      TEXT NOT NULL,
  content_hash TEXT UNIQUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata     JSONB DEFAULT '{}'::jsonb,
  tsv          tsvector GENERATED ALWAYS AS (
                to_tsvector('english', (COALESCE(title,'') || ' ' || content))
               ) STORED
);

CREATE INDEX IF NOT EXISTS idx_documents_source ON ross.documents (source);
CREATE INDEX IF NOT EXISTS idx_documents_tsv    ON ross.documents USING gin (tsv);
CREATE UNIQUE INDEX IF NOT EXISTS ux_documents_content_hash ON ross.documents (content_hash);

CREATE TABLE IF NOT EXISTS ross.document_chunks (
  id           BIGSERIAL PRIMARY KEY,
  document_id  BIGINT NOT NULL REFERENCES ross.documents(id) ON DELETE CASCADE,
  chunk_index  INTEGER NOT NULL,
  content      TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (document_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS idx_chunks_doc  ON ross.document_chunks (document_id);
CREATE INDEX IF NOT EXISTS idx_chunks_hash ON ross.document_chunks (content_hash);

CREATE TABLE IF NOT EXISTS ross.chunk_embeddings (
  id            BIGSERIAL PRIMARY KEY,
  chunk_id      BIGINT NOT NULL REFERENCES ross.document_chunks(id) ON DELETE CASCADE,
  model         TEXT NOT NULL,
  embedding_384 vector(384) NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (chunk_id, model)
);

CREATE INDEX IF NOT EXISTS idx_chunk_embeddings_chunk ON ross.chunk_embeddings (chunk_id);

CREATE TABLE IF NOT EXISTS ross.embedding_jobs (
  id           BIGSERIAL PRIMARY KEY,
  document_id  BIGINT NOT NULL REFERENCES ross.documents(id) ON DELETE CASCADE,
  model        TEXT NOT NULL DEFAULT 'text-embedding-3-small',
  status       TEXT NOT NULL DEFAULT 'pending',
  error        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  attempts     INTEGER NOT NULL DEFAULT 0,
  max_attempts INTEGER NOT NULL DEFAULT 3,
  claimed_at   TIMESTAMPTZ,
  claimed_by   TEXT,
  last_error   TEXT,
  CONSTRAINT embedding_jobs_status_check
    CHECK (status = ANY (ARRAY['pending','claimed','processing','completed','failed','dead']))
);

CREATE INDEX IF NOT EXISTS idx_embedding_jobs_status         ON ross.embedding_jobs (status);
CREATE INDEX IF NOT EXISTS idx_embedding_jobs_status_created ON ross.embedding_jobs (status, created_at);

CREATE TABLE IF NOT EXISTS ross.embeddings (
  id             BIGSERIAL PRIMARY KEY,
  document_id    BIGINT NOT NULL REFERENCES ross.documents(id) ON DELETE CASCADE,
  model          TEXT NOT NULL,
  embedding      vector,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  embedding_1536 vector(1536)
);

CREATE INDEX IF NOT EXISTS idx_embeddings_document_id ON ross.embeddings (document_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname='ross'
      AND indexname='idx_embeddings_hnsw_cosine_1536'
  ) THEN
    EXECUTE 'CREATE INDEX idx_embeddings_hnsw_cosine_1536 ON ross.embeddings USING hnsw (embedding_1536 vector_cosine_ops);';
  END IF;
END $$;

COMMIT;
