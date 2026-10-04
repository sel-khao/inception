FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
	ca-certificates \
	wget \
	mariadb-client \
	php8.2-fpm \
	php8.2-cli \
	php8.2-mysql \
	php8.2-curl \
	php8.2-gd \
	php8.2-mbstring \
	php8.2-xml \
	php8.2-zip \
	&& rm -rf /var/lib/apt/lists/*

RUN wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	-O /usr/local/bin/wp \
	&& chmod +x /usr/local/bin/wp

RUN mkdir -p /var/www/html /run/php

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY conf/wp-setup.sh /usr/local/bin/wp-setup.sh
RUN chmod +x /usr/local/bin/wp-setup.sh

EXPOSE 9000

CMD ["/usr/local/bin/wp-setup.sh"]
