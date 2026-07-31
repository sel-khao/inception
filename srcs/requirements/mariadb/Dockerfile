FROM debian:bookworm-slim

RUN apt update && apt install -y mariadb-server && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/mysqld && chown -R mysql:mysql /var/run/mysqld

COPY conf/mariadb-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY conf/init.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/init.sh

EXPOSE 3306

CMD ["/usr/local/bin/init.sh"]
