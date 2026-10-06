# User Documentation

This file is for someone who just wants to use the project: start it, open the website, log in, and check that everything works. No Docker knowledge is needed.

## 1. What services are provided

The stack has 3 services, each in its own container:

- nginx: the web server. It receives all visitors on port 443 (HTTPS). It is the only way in from outside.
- wordpress (with php-fpm): the website itself and its administration panel.
- mariadb: the database. It stores the posts, the users and the settings of the website.

The data is saved in 2 volumes, so nothing is lost when the project is stopped:

- the database (MariaDB)
- the website files (WordPress)

On the host machine, both are stored in /home/sel-khao/data.

## 2. Start and stop the project

Run all commands from the root of the project (the folder with the Makefile).

- Start (build and run): `make`
- Stop and remove the containers: `make down`
- Rebuild everything from scratch: `make re`
- Delete everything, including the data: `make fclean`

Warning: `make fclean` and `make re` delete the data (database and website files). Use `make down` then `make` if you only want to stop and restart.

After `make`, wait about 30 seconds. WordPress needs this time to install itself the first time. If you open the site too early you may see a 403 or 502 error. Wait a bit and reload.

## 3. Access the website and the administration panel

First time only: the domain name must point to your machine. This line must be in /etc/hosts:

```
127.0.0.1   sel-khao.42.fr
```

Then use these addresses:

- Website: https://sel-khao.42.fr
- Login page: https://sel-khao.42.fr/wp-login.php
- Administration panel: https://sel-khao.42.fr/wp-admin (it redirects to the login page if you are not logged in)

Your browser will show a security warning. This is normal: the certificate is self-signed (created by us, not by a public authority). Click on "Advanced" and then "Continue".

http://sel-khao.42.fr (port 80) does not work on purpose. Only HTTPS on port 443 is open.

To log in: open the login page, type the username and the password of the administrator, and you arrive on the dashboard. From the dashboard you can edit pages (Pages > edit > Update) and moderate comments.

## 4. Locate and manage the credentials

Passwords are never written in the Dockerfiles or in git. They are in local files:

- secrets/db_password.txt: password of the WordPress database user
- secrets/db_root_password.txt: password of the MariaDB root user
- secrets/credentials.txt: the WordPress passwords (administrator and normal user)
- srcs/.env: settings that are not secret (domain name, database name, usernames, emails)

The usernames of the two WordPress users are in srcs/.env (look for the WP_ variables).

To read a password:

```bash
cat secrets/db_password.txt
```

To change a password, edit the file and start again from zero, because the database remembers the old password:

```bash
make fclean
make
```

To change only a WordPress user's password without rebuilding, you can run:

```bash
docker exec wordpress wp user update <username> --user_pass='NewPassword' --allow-root --path=/var/www/html
```

(and then update the same password in the secrets file, so the file and reality match).

These files must never be pushed to git. They are listed in .gitignore.

## 5. Check that the services are running correctly

1. Are the 3 containers up?

```bash
docker ps
```

You should see nginx, wordpress and mariadb with the status "Up".

2. Does the website answer?

```bash
curl -k -I https://sel-khao.42.fr
```

You should get `HTTP/1.1 200 OK` (or a redirect 301 / 302).

3. Does HTTP stay closed?

```bash
curl -I http://sel-khao.42.fr
```

This must fail (connection refused).

4. Look at the logs if something seems wrong:

```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

Quick checklist:

- the 3 containers are Up
- the website opens in the browser (not the WordPress installation page)
- I can log in at /wp-admin
- a page I edited or a comment I wrote is still there after `make down` and `make`

Common problems:

- 403 or 502 right after `make`: WordPress is still installing. Wait 30 seconds.
- The site does not open at all: check the line in /etc/hosts, then `docker ps`.
- Still stuck: read the logs above, or try `make re` (this deletes the data).