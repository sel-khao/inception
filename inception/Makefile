NAME = inception

all:
	mkdir -p /home/sel-khao/data/mariadb /home/sel-khao/data/wordpress
	docker compose -f ./srcs/docker-compose.yml up -d --build

clean:
	docker compose -f ./srcs/docker-compose.yml down

fclean: clean
	docker compose -f ./srcs/docker-compose.yml down -v
	docker volume rm -f srcs_wordpress_data srcs_mariadb_data
	docker system prune -af
	sudo rm -rf /home/sel-khao/data/

re: fclean all

.PHONY: all clean fclean re

