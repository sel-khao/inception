NAME = inception

all:
	mkdir -p /home/selkhao/data/mariadb /home/selkhao/data/wordpress
	docker compose -f ./srcs/docker-compose.yml up -d --build

clean:
	docker compose -f ./srcs/docker-compose.yml down

fclean: clean
	docker system prune -af
	sudo rm -rf /home/selkhao/data/*

re: fclean all

.PHONY: all clean fclean re

