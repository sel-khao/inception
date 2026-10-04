*This project has been created as part of the 42 curriculum by <selkhao>.*

# Inception 🐳

## Description

Inception is a System Administration project where we build a small web infrastructure with **Docker Compose**, all inside a virtual machine.

The goal: instead of pulling ready-made images, we write **our own Dockerfiles** and get 3 services talking to each other, each in its own container:

| Service     | What it does                                  | Port (internal) |
|-------------|-----------------------------------------------|-----------------|
| `nginx`     | Web server, the **only entrypoint**, TLS 1.2/1.3 only | 443 (exposed)   |
| `wordpress` | WordPress + php-fpm (no nginx inside)         | 9000            |
| `mariadb`   | The database (no nginx inside)                | 3306            |

Plus:
- 2 **named volumes** (database + website files), stored on the host in `/home/selkhao/data`
- 1 **docker network** so the containers can talk to each other
- Containers **restart automatically** if they crash
- The site is reachable at **https://selkhao.42.fr**

### Project structure

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── docker-compose.yml
    ├── .env                  # non-secret variables 
    └── requirements/
        ├── mariadb/   (Dockerfile, conf)
        ├── nginx/     (Dockerfile, conf)
        └── wordpress/ (Dockerfile, conf)
```

### Main design choices

- **Base image:** Debian (penultimate stable, `bookworm`). Pinned version, **never** `latest`.
- **One service = one Dockerfile = one container.** Image name = service name.
- **No infinite-loop hacks** (`tail -f`, `sleep infinity`, `while true`). Each service runs its real daemon in the **foreground** as PID 1 (`nginx -g "daemon off;"`, `php-fpm -F`, `mysqld`/`mariadbd`), so Docker can handle signals and restarts properly.
- **No password in any Dockerfile.** Sensitive values come from **Docker secrets**; other config comes from the `.env` file.
- **Setup scripts** (in `tools/`) configure WordPress / MariaDB on first start, then `exec` the main process so it becomes PID 1.
- **WordPress has 2 users:** an administrator (username does *not* contain "admin") and a regular user.

### Comparisons (the "why did you choose that" part)

#### Virtual Machines vs Docker
| | Virtual Machine | Docker |
|---|---|---|
| What it virtualizes | Full hardware + its own OS kernel | Just the app + its dependencies |
| Kernel | Each VM has its own | **Shared** with the host |
| Size / speed | Heavy (GBs), slow to boot | Light (MBs), starts in seconds |
| Isolation | Very strong | Good, but weaker (shared kernel) |
| Best for | Running a whole different OS | Packaging and shipping one service |

👉 A container is **not** a mini-VM. It's an isolated process. That's why we run one service per container.

#### Secrets vs Environment Variables
| | Environment variables | Docker secrets |
|---|---|---|
| Stored in | `.env` / the container's environment | Files mounted in `/run/secrets/` (in memory) |
| Visible via | `docker inspect`, `env`, logs | Only inside the container, as a file |
| Good for | Non-sensitive config (domain name, DB name, usernames) | Passwords and anything confidential |

👉 I use **`.env` for config** and **secrets for passwords**.

#### Docker Network vs Host Network
| | Docker (bridge) network | Host network |
|---|---|---|
| Isolation | Containers get their own private network | Container shares the host's network directly |
| Name resolution | Containers reach each other by **service name** (`mariadb`, `wordpress`) | No built-in service names |
| Security | Only published ports are reachable | Everything the container listens on is exposed |
| In this project | ✅ Used | ❌ Forbidden (`network: host`, `links:`) |

#### Docker Volumes vs Bind Mounts
| | Named volume | Bind mount |
|---|---|---|
| Managed by | Docker | You (a raw host path) |
| Portability | Easy to move/back up with Docker commands | Depends on the host's folder layout |
| Permissions | Handled by Docker | Often messy (UID/GID conflicts) |
| In this project | ✅ Required | ❌ Not allowed for the 2 persistent volumes |

Our named volumes are configured with the `local` driver so their data lives in `/home/selkhao/data/` on the host.

---

## Instructions

### Prerequisites
- A Linux virtual machine (Debian/Ubuntu)
- `docker`, `docker compose` and `make` installed
- `sudo` rights

### 1. Domain name
Make `selkhao.42.fr` point to your local machine:

```bash
echo "127.0.0.1 selkhao.42.fr" | sudo tee -a /etc/hosts
```

### 2. Config and secrets
Create the files that are **not** in the repo (they're git-ignored):

- `srcs/.env` → domain name, DB name, DB user, WP usernames/emails… (no passwords)
- `secrets/db_password.txt`, `secrets/db_root_password.txt`, `secrets/credentials.txt` → the passwords

See `DEV_DOC.md` for the exact variables.

### 3. Build and run

```bash
make          # build the images and start everything
```

Then open **https://selkhao.42.fr** (accept the self-signed certificate warning).

### Useful commands

```bash
make down     # stop and remove containers
make clean    # stop + remove containers/networks
make fclean   # full cleanup (images, volumes, data)
make re       # rebuild everything from scratch
```

📖 More details: [`USER_DOC.md`](USER_DOC.md) (for users/admins) and [`DEV_DOC.md`](DEV_DOC.md) (for developers).

---

## Resources

### References
- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Dockerfile best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [NGINX `ssl_protocols`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [WordPress developer docs](https://developer.wordpress.org/)
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
- [MariaDB knowledge base](https://mariadb.com/kb/en/)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- Articles about **PID 1 and signal handling in containers**

### How AI was used

- **Understanding concepts:** asked AI to explain PID 1, FastCGI, Docker secrets, named volumes vs bind mounts, and TLS configuration.
- **Debugging:** pasted error messages (e.g. MariaDB not ready, php-fpm socket issues) to get ideas of what to check.
- **Documentation:** used AI to help structure and draft this README, `USER_DOC.md` and `DEV_DOC.md`.
- **What I did myself:** wrote and tested the Dockerfiles, compose file, scripts and Makefile. Everything AI suggested was **read, tested, and verified with my peers** — I can explain every line of the project.
