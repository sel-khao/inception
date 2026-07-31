FROM debian:bookworm-slim

RUN apt update && apt install -y \
	 wget \
	 php8.2 \
	 php8.2-fpm \
	 php8.2-mysql \
	 && rm -rf /var/lib/apt/lists/*

RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x wp-cli.phar \
	&& mv wp-cli.phar /usr/local/bin/wp

RUN mkdir -p /var/www/html \
	&& cd /var/www/html \
	&& wp core download --allow-root

COPY conf/wp-config.php /var/www/html/wp-config.php
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

RUN chown -R www-data:www-data /var/www/html

EXPOSE 9000

CMD ["php-fpm8.2", "-F"]
