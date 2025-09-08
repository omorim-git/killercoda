#!/bin/bash
echo "[INFO] Updating apt sources to use mirrors.edge.kernel.org..."

# バックアップを保存
sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak.$(date +%s)

# コードネーム取得 (例: noble, jammy)
CODENAME=$(lsb_release -sc)
ARCH=$(dpkg --print-architecture)

# ubuntu.sources を置き換え
sudo sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirrors.iitd.ac.in/ubuntu|g' \
    /etc/apt/sources.list.d/ubuntu.sources

echo "[INFO] Running apt-get update..."
sudo apt-get update -y

echo "[INFO] Installing nginx..."
sudo apt-get install -y nginx

echo "[INFO] Configuring nginx demo site..."

# デモ用ディレクトリ
sudo mkdir -p /var/www/demo/assets

# Nginx 設定
sudo tee /etc/nginx/sites-available/demo > /dev/null <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/demo;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # キャッシュ設定
    location /assets/ {
        add_header Cache-Control "public, max-age=31536000, immutable";
        try_files $uri =404;
    }

    location = /index.html {
        add_header Cache-Control "no-cache";
    }
}
NGINX

# 有効化
sudo ln -sf /etc/nginx/sites-available/demo /etc/nginx/sites-enabled/default

# 構文テスト & リロード
echo "[INFO] Testing nginx configuration..."
sudo nginx -t
echo "[INFO] Reloading nginx..."
sudo systemctl reload nginx

# 自動起動
sudo systemctl enable nginx
# 準備完了表示
touch /tmp/background-finished