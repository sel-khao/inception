all:
	docker compose -f ./srcs/docker-compose.yml up -d --build

clean:
	docker compose -f ./srcs/docker-compose.yml down

flcean:
	docker compose -f ./srcs/docker-compose.yml down -v docker system prune -af

re: clean all

.PHONY: all clean fclean re

