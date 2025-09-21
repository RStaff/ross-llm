.PHONY: up down logs db-migrate
up:
\tdocker compose up -d --build
down:
\tdocker compose down
logs:
\tdocker compose logs -f
db-migrate:
\tcat packages/retriever/sql/001_init.sql | docker compose exec -T db psql -U postgres -d rossllm
