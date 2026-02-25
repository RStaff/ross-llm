.PHONY: up down logs db-migrate
up:
	 docker compose up -d --build
down:
	 docker compose down
logs:
	 docker compose logs -f
db-migrate:
	 cat packages/retriever/sql/001_init.sql | docker compose exec -T db psql -U postgres -d rossllm
