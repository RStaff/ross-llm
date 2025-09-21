CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS documents (
  id bigserial PRIMARY KEY,
  source text, path text, created_at timestamptz default now()
);
CREATE TABLE IF NOT EXISTS chunks (
  id bigserial PRIMARY KEY,
  document_id bigint REFERENCES documents(id),
  content text,
  embedding vector(1024),
  created_at timestamptz default now()
);
CREATE INDEX IF NOT EXISTS chunks_embedding_idx
ON chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists=100);
