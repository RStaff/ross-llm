#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "== Ross-LLM Path B: add RossCloud schema into db =="
echo "Repo: $REPO_ROOT"
echo

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker not found. Install Docker Desktop or Colima."
  exit 1
fi

# Pick compose command: prefer `docker compose`, fallback to `docker-compose`
COMPOSE=""
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "❌ Neither 'docker compose' nor 'docker-compose' is available."
  echo "   If you're on Docker Desktop, update Docker."
  echo "   If you're on Colima, install docker-compose plugin or use docker-compose binary."
  exit 1
fi

echo "✅ Using compose: $COMPOSE"
echo

# Verify Docker daemon is reachable
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon not reachable."
  echo "   Start Docker Desktop (or run: colima start) and retry."
  exit 1
fi

# Verify compose works here
if ! $COMPOSE config >/dev/null 2>&1; then
  echo "❌ Compose can't load a config in this directory."
  echo "   Expected docker-compose.yml or compose.yml in: $REPO_ROOT"
  echo "   Found:"
  ls -la | sed 's/^/   /'
  exit 1
fi

DB_SERVICE="db"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-rossllm}"

echo "🔎 Current stack status:"
$COMPOSE ps || true
echo

echo "🧱 Writing migration SQL..."
SQL_FILE="packages/retriever/sql/002_rosscloud_schema.sql"

cat > "$SQL_FILE" <<'SQL'
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
SQL

echo "✅ Wrote: $SQL_FILE"
echo

echo "🚀 Ensuring DB service is up..."
$COMPOSE up -d "$DB_SERVICE"

echo "⏳ Waiting for DB to accept connections..."
tries=0
max_tries=30
while true; do
  ((tries++)) || true
  if $COMPOSE exec -T "$DB_SERVICE" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    break
  fi
  if [ "$tries" -ge "$max_tries" ]; then
    echo "❌ DB didn't become ready."
    $COMPOSE logs "$DB_SERVICE" --tail=200 || true
    exit 1
  fi
  sleep 1
done
echo "✅ DB is ready."
echo

echo "🗃️  Applying migration..."
cat "$SQL_FILE" | $COMPOSE exec -T "$DB_SERVICE" psql -U "$DB_USER" -d "$DB_NAME"

echo
echo "🔧 Setting DB-level search_path (ross, public) for user '$DB_USER'..."
$COMPOSE exec -T "$DB_SERVICE" psql -U "$DB_USER" -d "$DB_NAME" -c \
"ALTER ROLE ${DB_USER} IN DATABASE ${DB_NAME} SET search_path = ross, public;"

echo
echo "✅ Done. Tables in ross schema:"
$COMPOSE exec -T "$DB_SERVICE" psql -U "$DB_USER" -d "$DB_NAME" -c \
"SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema='ross' ORDER BY table_name;"

