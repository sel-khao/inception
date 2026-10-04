# Developer Documentation 🛠️

This guide explains how to set up, build, and manage the project from scratch, and also has a **cheat sheet** of commands and explanations that are handy for the evaluation.

---

## 1. Set up the environment from scratch

### Prerequisites
- A Linux **virtual machine** (Debian/Ubuntu)
- `docker`, `docker compose` (v2) and `make`
- Your user in the `docker` group (or use `sudo`)

```bash
sudo apt update && sudo apt install -y make docker.io docker-compose-v2
sudo usermod -aG docker $USER      # then log out / log in
```

### Domain name
```bash
echo "127.0.0.1 selkhao.42.fr" | sudo tee -a /etc/hosts
```

### Configuration files (not in git!)

**`srcs/.env`** — non-secret variables. Example (adapt the names to yours):
```env
DOMAIN_NAME=selkhao.42.fr

# MariaDB
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

# WordPress
WP_TITLE=Inception
WP_ADMIN_USER=selkhao_boss        # must NOT contain "admin"/"administrator"
WP_ADMIN_EMAIL=selkhao@student.42.fr
WP_USER=selkhao_user
WP_USER_EMAIL=user@student.42.fr
```

**`secrets/`** — one file per secret (no trailing junk, just the password):
```
secrets/db_password.txt
secrets/db_root_password.txt
secrets/credentials.txt
```

**`.gitignore`** must contain:
```
secrets/
srcs/.env
```

### Data folders on the host
The volumes store data in `/home/selkhao/data/`. The Makefile creates them:
```bash
mkdir -p /home/selkhao/data/mariadb /home/selkhao/data/wordpress
```

---

## 2. Build and launch

```bash
make            # = create data dirs + docker compose up -d --build
```

What the Makefile does (typical targets):

| Target | What it does |
|---|---|
| `make` / `make all` | Creates the data folders, builds the images, starts the containers |
| `make down` | `docker compose down` (stops + removes containers and network) |
| `make clean` | Down + removes unused images/containers |
| `make fclean` | Clean + removes volumes and the data in `/home/selkhao/data` |
| `make re` | `fclean` then `all` |

Under the hood:
```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build
```

---

## 3. Useful commands to manage containers and volumes

### Containers
```bash
docker ps                         # running containers
docker ps -a                      # all containers
docker logs -f wordpress          # follow logs of a container
docker exec -it mariadb bash      # open a shell inside a container
docker compose -f srcs/docker-compose.yml restart nginx
docker compose -f srcs/docker-compose.yml ps
```

### Images
```bash
docker images                     # list images (names = service names, no "latest" tag in the Dockerfile!)
docker compose -f srcs/docker-compose.yml build --no-cache
```

### Volumes
```bash
docker volume ls
docker volume inspect srcs_db_data      # shows the real path on the host
ls /home/selkhao/data/mariadb
ls /home/selkhao/data/wordpress
```

### Network
```bash
docker network ls
docker network inspect srcs_inception   # shows the 3 containers attached
```

### Nuke everything (careful 💣)
```bash
docker compose -f srcs/docker-compose.yml down -v
docker system prune -af
sudo rm -rf /home/selkhao/data/*
```

---

## 4. Where is the data stored and how does it persist?

| Data | Container path | Docker named volume | Host path |
|---|---|---|---|
| Database | `/var/lib/mysql` | `db_data` | `/home/selkhao/data/mariadb` |
| WordPress files | `/var/www/html` | `wp_data` | `/home/selkhao/data/wordpress` |

- Both are **named volumes** (not bind mounts in the compose service definition). They use the `local` driver with `driver_opts` (`type: none`, `o: bind`, `device: /home/selkhao/data/...`) so Docker manages them **and** the files land in the right host folder.
- NGINX also mounts the WordPress volume (read-only is nice) because it needs to serve the static files (CSS, images, JS).
- Data **survives** `make down` and container crashes. It's only deleted by `make fclean` / `down -v` + removing the host folders.

---

## 5. 🎓 Evaluation cheat sheet

### Quick explanations (say it in your own words!)

**What is Docker, and how is it different from a VM?**
Docker runs apps as isolated processes that **share the host kernel**. A VM emulates a whole machine with its own OS. Docker = lighter and faster.

**What is Docker Compose?**
A tool to define and run several containers (+ network + volumes) in one `docker-compose.yml` file, with one command.

**Why Dockerfiles instead of pulling images?**
The subject wants us to build our own images from Debian so we understand what's inside. Only the base image (Debian) is pulled.

**What is PID 1 and why no `tail -f` / `sleep infinity`?**
The first process in a container is PID 1: when it stops, the container stops. It also receives the stop signals (SIGTERM). If PID 1 is a fake loop, the real service isn't managed properly (no clean shutdown, zombie processes). So each service runs **directly in the foreground** (`nginx -g "daemon off;"`, `php-fpm -F`, `mariadbd`). In scripts I use `exec` so the daemon *replaces* the script and becomes PID 1.

**How do the services talk to each other?**
Through the custom docker network, by **service name** (Docker's built-in DNS): WordPress connects to `mariadb:3306`, NGINX passes PHP to `wordpress:9000` via FastCGI.

**Why is NGINX the only entrypoint?**
Security: only port 443 is published to the host. WordPress (9000) and MariaDB (3306) are only reachable inside the docker network.

**Why TLS 1.2/1.3 only?**
Older versions (SSL, TLS 1.0/1.1) are insecure. Configured in nginx with `ssl_protocols TLSv1.2 TLSv1.3;`.

**Secrets vs env variables?**
Env variables are visible with `docker inspect`; secrets are mounted as files in `/run/secrets/` and are safer for passwords.

**What does `restart: unless-stopped` (or `always`) do?**
Restarts the container automatically if it crashes (or after a reboot of the Docker daemon).

---

### Commands to run live

**1) Show the project is up**
```bash
docker ps
docker compose -f srcs/docker-compose.yml ps
```

**2) No forbidden stuff**
```bash
grep -rn "network_mode\|links:\|--link" srcs/        # nothing
grep -rn "tail -f\|sleep infinity\|while true" srcs/ # nothing
grep -rn "latest" srcs/                              # nothing
grep -n "networks" srcs/docker-compose.yml           # network line present
```

**3) Network**
```bash
docker network ls
docker network inspect srcs_inception
```

**4) Volumes**
```bash
docker volume ls
docker volume inspect srcs_db_data
docker volume inspect srcs_wp_data
ls -la /home/selkhao/data
```

**5) Port 443 only / HTTP refused**
```bash
curl -k -I https://selkhao.42.fr     # works
curl -I http://selkhao.42.fr         # connection refused (port 80 closed)
```

**6) TLS versions**
```bash
openssl s_client -connect selkhao.42.fr:443 -tls1_2   # works
openssl s_client -connect selkhao.42.fr:443 -tls1_3   # works
openssl s_client -connect selkhao.42.fr:443 -tls1_1   # must FAIL
```

**7) Processes / PID 1 of each container**
```bash
docker exec nginx ps aux          # PID 1 = nginx
docker exec wordpress ps aux      # PID 1 = php-fpm
docker exec mariadb ps aux        # PID 1 = mariadbd / mysqld
```
*(If `ps` isn't installed in the container, use `docker top nginx`.)*

**8) Database: show the 2 WordPress users**
```bash
docker exec -it mariadb mariadb -u root -p
# (type the root password from secrets/db_root_password.txt)
SHOW DATABASES;
USE wordpress;
SELECT user_login, user_email FROM wp_users;
```
or with WP-CLI (if installed in my wordpress image):
```bash
docker exec wordpress wp user list --path=/var/www/html --allow-root
```

**9) Restart after crash**
```bash
docker kill wordpress
docker ps          # a few seconds later it's back "Up"
```

**10) Persistence test**
1. Log in to `/wp-admin`, write a post or a comment.
2. `make down` then `make`.
3. Reload the site → the post is still there ✅

**11) Check no password in Dockerfiles / git**
```bash
grep -rni "password" srcs/requirements/*/Dockerfile
git ls-files | grep -E "secrets|\.env"       # must print nothing
```

---

### Possible "modify the project" requests (be ready)
- **Change the port** NGINX listens on → edit `ports:` in compose + `listen` in nginx conf, then `docker compose up -d --build nginx`.
- **Change a WordPress user / title** → edit `.env`, `make re`.
- **Change the domain name** → `.env` + `/etc/hosts` + nginx `server_name` + the SSL certificate CN.
- **Rebuild only one service** → `docker compose -f srcs/docker-compose.yml up -d --build nginx`.

💡 Tip: if you don't remember something, **explain how you'd find it** (`docker logs`, `docker inspect`, the docs). That shows real understanding.