#!/bin/bash
set -e

WP_PATH=/var/www/html
DB_HOST="${WP_DB_HOST:-mariadb:3306}"
DB_ADDR="${DB_HOST%%:*}"
DB_PORT="${DB_HOST##*:}" 

echo "Waiting for MariaDB at ${DB_ADDR}:${DB_PORT}..."
until mysql -h"${DB_ADDR}" -P"${DB_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" -e "SELECT 1" >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "${tries}" -ge 30 ]; then
        echo "MariaDB is not reachable, giving up." >&2
        exit 1
    fi
    sleep 2
done
echo "MariaDB is ready."

# 2. Download WordPress into the volume only if it is not there yet.
if [ ! -f "${WP_PATH}/wp-load.php" ]; then
    echo "Downloading WordPress..."
    wp core download --path="${WP_PATH}" --allow-root
fi

# 3. Create wp-config.php from the environment variables (no password in the image).
if [ ! -f "${WP_PATH}/wp-config.php" ]; then
    echo "Creating wp-config.php..."
    wp config create --path="${WP_PATH}" --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="${DB_HOST}"
fi

# 4. Install WordPress and create the two users, only the first time.
if ! wp core is-installed --path="${WP_PATH}" --allow-root; then
    echo "Installing WordPress..."
    wp core install --path="${WP_PATH}" --allow-root --skip-email \
        --url="${WP_URL}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}"

    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --path="${WP_PATH}" --allow-root \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=author
fi

# 5. php-fpm (running as www-data) must own the files, then become PID 1.
chown -R www-data:www-data "${WP_PATH}"
mkdir -p /run/php

echo "Starting php-fpm..."
exec php-fpm8.2 -F