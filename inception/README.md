*This project has been created as part of the 42 curriculum by selkhao.*

# Inception

## Description

Inception is a system administration project. The goal is to build a small web infrastructure with Docker Compose, inside a virtual machine.

I did not use ready-made images. I wrote my own Dockerfile for each service, built from Debian. There are 3 services, each one in its own container:

- nginx: the web server. It is the only entrypoint, on port 443, with TLS 1.2 / 1.3 only.
- wordpress: WordPress with php-fpm (listens on port 9000). No nginx inside.
- mariadb: the database (listens on port 3306). No nginx inside.

Also part of the project:

- 2 named volumes: one for the database, one for the WordPress files. Their data is stored on the host in /home/selkhao/data.
- 1 docker network, so the containers can talk to each other.
- The containers restart automatically if they crash.
- The website is available at https://selkhao.42.fr

How a request travels:

```
browser --443 (HTTPS)--> nginx --9000 (FastCGI)--> wordpress (php-fpm) --3306--> mariadb
```

### Project structure

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/                  (not in git)
└── srcs/
    ├── docker-compose.yml
    ├── .env                  (not in git)
    └── requirements/
        ├── mariadb/    (Dockerfile, conf/, tools/)
        ├── nginx/      (Dockerfile, conf/, tools/)
        └── wordpress/  (Dockerfile, conf/, tools/)
```

- Makefile: builds and starts everything with docker compose.
- srcs/docker-compose.yml: describes the services, the network and the volumes.
- srcs/.env: non-secret variables (domain name, database name, usernames).
- secrets/: the passwords, one per file. Never pushed to git.
- requirements/<service>/: the Dockerfile and config files of one service.

### Design choices

- Base image: Debian bookworm (the penultimate stable version). The version is written explicitly, never "latest".
- One service = one Dockerfile = one container. The image name is the same as the service name.
- No infinite loop tricks (tail -f, sleep infinity, while true). Each service runs its real program in the foreground, as PID 1 (nginx with "daemon off;", php-fpm with -F, mariadb). This way Docker can stop and restart it properly.
- The setup scripts (for MariaDB and WordPress) run on the first start, then use exec to replace themselves with the real program.
- No password in any Dockerfile. Passwords come from Docker secrets, other settings come from the .env file.
- WordPress has 2 users: an administrator (the username does not contain "admin") and a normal user.
- nginx uses a self-signed certificate. The browser shows a warning, which is expected.

### Comparisons

**Virtual Machines vs Docker**

A virtual machine emulates a full computer and runs its own operating system with its own kernel. It is heavy (GBs) and slow to start, but very isolated. A Docker container is just an isolated process that shares the kernel of the host. It is light (MBs) and starts in seconds, but the isolation is weaker. That is why Docker is a good fit for running one service per container.

**Secrets vs Environment Variables**

Environment variables are simple, but anyone who can run `docker inspect` or `env` can read them. Docker secrets are mounted as files in /run/secrets/ inside the container, so they are not shown in docker inspect. I use the .env file for normal settings (domain name, database name, usernames) and secrets for passwords.

**Docker Network vs Host Network**

On a Docker network, containers get their own private network and find each other by service name (for example `mariadb`). Only the ports we publish are reachable from outside. With the host network, the container shares the network of the host with no isolation. That is why `network: host` (and links) is forbidden here. In my project only nginx publishes a port (443).

**Docker Volumes vs Bind Mounts**

A named volume is created and managed by Docker and used by its name. A bind mount links a specific folder of the host directly into the container, and it often causes permission problems. The subject asks for named volumes. Mine use the local driver with driver_opts, so Docker manages them and the data is still stored in /home/selkhao/data on the host.

---

## Instructions

### Prerequisites

- A Linux virtual machine (Debian or Ubuntu)
- docker, docker compose and make installed
- sudo rights

### 1. Domain name

Make selkhao.42.fr point to your machine:

```bash
echo "127.0.0.1 selkhao.42.fr" | sudo tee -a /etc/hosts
```

### 2. Configuration and secrets

These files are not in the repository (they are in .gitignore), so create them:

- srcs/.env: domain name, database name, database user, WordPress usernames and emails (no passwords)
- secrets/db_password.txt, secrets/db_root_password.txt, secrets/credentials.txt: the passwords

The exact variables are listed in DEV_DOC.md.

### 3. Build and run

```bash
make
```

Wait about 30 seconds for WordPress to finish installing, then open https://selkhao.42.fr and accept the certificate warning.

### Other commands

```bash
make down     # stop and remove the containers
make clean    # stop and remove containers, network and unused images
make fclean   # full cleanup, including volumes and the data in /home/selkhao/data
make re       # fclean + build again from scratch
```

More details: USER_DOC.md (for users and administrators) and DEV_DOC.md (for developers).

---

## Resources

### References

- Docker documentation: https://docs.docker.com/
- Docker Compose file reference: https://docs.docker.com/compose/compose-file/
- Dockerfile best practices: https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- Docker secrets with Compose: https://docs.docker.com/compose/how-tos/use-secrets/
- NGINX documentation: https://nginx.org/en/docs/
- NGINX ssl module (ssl_protocols): https://nginx.org/en/docs/http/ngx_http_ssl_module.html
- WordPress developer documentation: https://developer.wordpress.org/
- WP-CLI handbook: https://make.wordpress.org/cli/handbook/
- MariaDB knowledge base: https://mariadb.com/kb/en/
- PHP-FPM configuration: https://www.php.net/manual/en/install.fpm.configuration.php
- Articles about PID 1 and signal handling in containers

### How AI was used

- To understand concepts: PID 1, FastCGI, Docker secrets, named volumes vs bind mounts, TLS configuration in nginx.
- To debug: I pasted error messages (for example "MariaDB not reachable", 502 Bad Gateway, a wrong port in the wordpress setup script) to get ideas of what to check.
- To help structure and simplify this README, USER_DOC.md and DEV_DOC.md.
