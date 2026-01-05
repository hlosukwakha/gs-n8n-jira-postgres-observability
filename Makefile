.PHONY: up down logs ps restart clean

up:
	docker compose up -d --remove-orphans

down:
	docker compose down

restart:
	docker compose down && docker compose up -d --remove-orphans

ps:
	docker compose ps

logs:
	docker compose logs -f --tail=200

clean:
	docker compose down -v
