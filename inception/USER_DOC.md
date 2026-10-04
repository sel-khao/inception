# User Documentation 👩‍💻

This guide is for anyone who just wants to **use** the project: start it, open the website, and check that everything works. No Docker knowledge needed!

---

## 1. What does this stack provide?

| Service | What it is | Why it's there |
|---|---|---|
| **NGINX** | A web server | Receives all visitors on port **443 (HTTPS)** and is the *only* door into the infrastructure |
| **WordPress + PHP-FPM** | The website itself | Runs the WordPress site and its admin panel |
| **MariaDB** | A database | Stores all WordPress content (posts, users, settings) |

Your data is saved in **two volumes**, so nothing is lost when you stop the project:
- the **database** (MariaDB)
- the **website files** (WordPress)

---

## 2. Start and stop the project

Everything is done from the **root of the project** (where the `Makefile` is).

| Action | Command |
|---|---|
| ▶️ Start (build + run) | `make` |
| ⏹️ Stop and remove containers | `make down` |
| 🔄 Rebuild everything from scratch | `make re` |
| 🧹 Delete everything, including data | `make fclean` |

> ⚠️ `make fclean` **deletes your data** (database + website files). Only use it if you want a fresh start!

---

## 3. Access the website and the admin panel

First time only — make sure the domain points to your machine. In `/etc/hosts` there must be this line:

```
127.0.0.1   <login>.42.fr
```

Then:

| What | Address |
|---|---|
| 🌐 Website | https://<login>.42.fr |
| 🔐 Admin panel | https://<login>.42.fr/wp-admin |

💡 Your browser will show a **security warning**. That's normal: the certificate is self-signed (made by us, not by a public authority). Click *Advanced → Continue*.

❌ `http://` (port 80) does **not** work on purpose. Only HTTPS on port 443.

---

## 4. Locate and manage credentials

Passwords are **never** written in the Dockerfiles or in git. They live in local files:

| File | Contains |
|---|---|
| `secrets/db_password.txt` | Password of the WordPress database user |
| `secrets/db_root_password.txt` | Password of the MariaDB root user |
| `secrets/credentials.txt` | WordPress admin / user passwords |
| `srcs/.env` | Non-secret config: domain name, DB name, usernames, emails |

To see a password:
```bash
cat secrets/db_password.txt
```

To **change** a password: edit the file, then rebuild with a fresh start:
```bash
make fclean && make
```
(The database stores the old password, so a clean rebuild is needed.)

> 🔒 These files must **never** be pushed to git (they're in `.gitignore`).

---

## 5. Check that everything is running

**1. Are the 3 containers up?**
```bash
docker ps
```
You should see `nginx`, `wordpress` and `mariadb` with status **Up**.

**2. Does the website answer?**
```bash
curl -k -I https://<login>.42.fr
```
You should get `HTTP/1.1 200 OK` (or a redirect `301/302`).

**3. Read the logs if something looks wrong**
```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

**4. Quick checklist ✅**
- [ ] The 3 containers are `Up`
- [ ] The website opens in the browser
- [ ] I can log in to `/wp-admin`
- [ ] A post I created is still there after `make down` + `make`

**Something broke?** → try `make re`. Still stuck? Look at the logs above.