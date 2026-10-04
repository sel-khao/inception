FROM debian:bookworm-slim

RUN apt update && apt install -y nginx openssl && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl

RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout /etc/nginx/ssl/selkhao.42.fr.key \
		-out /etc/nginx/ssl/selkhao.42.fr.ctr \
		-subj "/CN=selkhao.42.fr"

COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
