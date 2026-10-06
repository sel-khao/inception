# Developer Documentation

This file explains how to set up, build and manage the project from scratch. At the end there is a cheat sheet with explanations and commands that are useful for the evaluation.

## 1. Set up the environment from scratch

### Prerequisites

- A Linux virtual machine (Debian or Ubuntu)
- docker, docker compose (v2) and make
- Your user in the docker group (or use sudo)

```bash
sudo apt update && sudo apt install -y make docker.io docker-compose-v2
sudo usermod -aG docker $USER     # then log out and log in again
```

### Domain name

```bash
echo "127.0.0.1 selkhao.42.fr" | sudo tee -a /etc/hosts
```

### Configuration files (not in git)

srcs/.env contains the settings that are not secret. Example (adapt to your own file):

```env
DOMAIN_NAME=selkhao.42.fr

# MariaDB
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

# WordPress
WP_TITLE=Inception
WP_ADMIN_USER=<admin username, must NOT contain "admin" or "administrator">
WP_ADMIN_EMAIL=<email>
WP_USER=<second user>
WP_USER_EMAIL=<email>
```

The secrets folder has one file per password (only the password inside the file):

```
secrets/db_password.txt
secrets/db_root_password.txt
secrets/credentials.txt
```

The .gitignore must contain:

```
secrets/
srcs/.env
```

### Data folders on the host

The volumes store their data in /home/selkhao/data. The Makefile creates the folders, but you can also do it by hand:

```bash
sudo mkdir -p /home/selkhao/data/mariadb /home/selkhao/data/wordpress
```

## 2. Build and launch

```bash
make
```

The Makefile targets:

- make (or make all): creates the data folders, builds the images and starts the containers
- make down: stops and removes the containers and the network
- make clean: down, and removes unused images
- make fclean: clean, and removes the volumes and the data in /home/selkhao/data
- make re: fclean and then all

Under the hood, make runs something like:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build
```

Startup order and timing: mariadb starts first, then wordpress waits until the database answers, downloads WordPress, creates wp-config.php, installs the site and creates the 2 users, and only then starts php-fpm. nginx is already running by that time. So for about 30 seconds after make you can see a 403 or a 502 from nginx. This is normal, just wait.

## 3. Commands to manage the containers and the volumes

### Containers

```bash
docker ps                                   # running containers
docker ps -a                                # all containers
docker logs -f wordpress                    # follow the logs of one container
docker exec -it mariadb bash                # open a shell inside a container
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml restart nginx
docker compose -f srcs/docker-compose.yml up -d --build nginx    # rebuild only one service
```

### Images

```bash
docker images
docker compose -f srcs/docker-compose.yml build --no-cache
```

### Volumes

```bash
docker volume ls
docker volume inspect srcs_mariadb_data      # the "device" line shows the host path
docker volume inspect srcs_wordpress_data
ls -la /home/selkhao/data/mariadb
ls -la /home/selkhao/data/wordpress
```

### Network

```bash
docker network ls
docker network inspect <network name>        # the 3 containers are listed inside
```

### Delete everything (careful)

```bash
make fclean
# or by hand:
docker compose -f srcs/docker-compose.yml down -v
docker system prune -af
sudo rm -rf /home/selkhao/data/*
```

## 4. Where the data is stored and how it persists

- Database: /var/lib/mysql in the mariadb container, volume srcs_mariadb_data, host path /home/selkhao/data/mariadb
- WordPress files: /var/www/html in the wordpress container, volume srcs_wordpress_data, host path /home/selkhao/data/wordpress

Both are Docker named volumes. They use the local driver with driver_opts (type: none, o: bind, device: /home/selkhao/data/...). So Docker manages them by name, and the files are really stored in the folder required by the subject.

nginx also mounts the WordPress volume, because it serves the static files (CSS, images, JS) itself.

The data survives make down, a container crash and a reboot of the VM. It is only deleted by make fclean (or down -v and removing the host folders).

## 5. Changing a port (practice for the evaluation)

In every case, finish with `make re` (or at least a rebuild), then check with the commands in the cheat sheet. First find all the places where the port appears:

```bash
grep -rn "3306" srcs/ Makefile
```

### MariaDB (3306 to a new port)

4 places to change:

1. `port = ...` in the mariadb .cnf file (under [mysqld])
2. `EXPOSE` in the mariadb Dockerfile
3. `WP_DB_HOST=mariadb:NEWPORT` in srcs/.env
4. anything else that hardcodes the port (the grep shows it)

If WordPress was already installed, wp-config.php (in the volume) still has the old port. Fix it with:

```bash
docker exec wordpress wp config set DB_HOST mariadb:NEWPORT --allow-root --path=/var/www/html
```

or rebuild from zero with make fclean && make.

In the wordpress setup script, the host and the port must be split for the mysql client (-h mariadb -P NEWPORT). WP-CLI accepts host:port in one string for --dbhost.

### WordPress / php-fpm (9000 to a new port)

3 places to change, and they must match:

1. the listen directive of php-fpm (www.conf, or the sed in the wordpress Dockerfile)
2. `EXPOSE` in the wordpress Dockerfile
3. `fastcgi_pass wordpress:NEWPORT;` in the nginx conf

If the two sides do not match, nginx shows 502 Bad Gateway and docker logs nginx says "connect() failed ... upstream".

### nginx (443 to a new port)

1. `listen NEWPORT ssl;` in the nginx conf
2. `ports: - "NEWPORT:NEWPORT"` in docker-compose.yml
3. open https://selkhao.42.fr:NEWPORT

### Commands to run live

1. Show that the project is up

```bash
docker ps
docker compose -f srcs/docker-compose.yml ps
```

2. No forbidden things

```bash
grep -rn "network_mode\|links:\|--link" srcs/ Makefile      # nothing
grep -rn "tail -f\|sleep infinity\|while true" srcs/        # nothing
grep -rn "latest" srcs/                                     # nothing
grep -n "networks" srcs/docker-compose.yml                  # the network line is there
grep -rni "password" srcs/requirements/*/Dockerfile         # no real password
```

3. Network

```bash
docker network ls
docker network inspect <network name>
```

4. Volumes

```bash
docker volume ls
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
ls -la /home/selkhao/data
```

5. Only port 443 is open

```bash
curl -k -I https://selkhao.42.fr      # works
curl -I http://selkhao.42.fr          # connection refused
```

6. TLS versions

```bash
openssl s_client -connect selkhao.42.fr:443 -tls1_2    # works
openssl s_client -connect selkhao.42.fr:443 -tls1_3    # works
openssl s_client -connect selkhao.42.fr:443 -tls1_1    # must fail
```

7. What runs as PID 1 in each container

```bash
docker top nginx
docker top wordpress
docker top mariadb
```

8. Database: show the 2 WordPress users

```bash
docker exec -it mariadb mariadb -u root -p
SHOW DATABASES;
USE wordpress;
SELECT user_login, user_email FROM wp_users;
```

or with WP-CLI:

```bash
docker exec wordpress wp user list --allow-root --path=/var/www/html
```

9. Restart after a crash

```bash
docker kill wordpress
docker ps          # a few seconds later it is Up again
```

10. Persistence test

- Log in to /wp-admin, edit a page and write a comment.
- Reboot the VM (or make down), then run make again.
- Wait 30 seconds and reload: the changes are still there.

11. Nothing secret in git

```bash
git ls-files | grep -E "secrets|\.env"       # must print nothing
```

### "Modify the project" requests to be ready for

- Change the port of mariadb, wordpress or nginx: see section 5, then make re.
- Change a WordPress username or the site title: edit srcs/.env, then make fclean && make.
- Change the domain name: .env, /etc/hosts, server_name in nginx, the certificate CN, then make fclean && make.
- Rebuild only one service: `docker compose -f srcs/docker-compose.yml up -d --build nginx`.
