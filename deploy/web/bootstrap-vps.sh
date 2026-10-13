#!/usr/bin/env bash
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-/var/www/shoppefood}"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx git curl unzip rsync ufw

ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

install -d -o www-data -g www-data "$DEPLOY_PATH"

cat >/etc/nginx/sites-available/shoppefood <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /var/www/shoppefood;
    index index.html;

    location = /healthz {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "ok\n";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$ {
        expires 7d;
        add_header Cache-Control "public";
        try_files $uri =404;
    }
}
NGINX

ln -sfn /etc/nginx/sites-available/shoppefood /etc/nginx/sites-enabled/shoppefood
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl restart nginx

printf 'USER=%s\n' "$(whoami)"
. /etc/os-release
printf 'OS=%s %s\n' "$NAME" "$VERSION_ID"
ufw status verbose
systemctl is-active nginx
curl -fsS http://127.0.0.1/healthz
