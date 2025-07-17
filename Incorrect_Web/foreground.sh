#!/bin/bash

# Apacheをインストール
apt update && apt install -y apache2

# mod_headers を有効化
a2enmod headers

# .htaccess を有効にするために AllowOverride を変更（必要に応じてバックアップ）
sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Cache-Control を設定する .htaccess を作成
cat <<EOF > /var/www/html/.htaccess
<IfModule mod_headers.c>
  <FilesMatch "\.(html|css|js)$">
    Header set Cache-Control "public, max-age=3600"
  </FilesMatch>
</IfModule>
EOF

# サーバ起動
systemctl restart apache2

# 準備完了表示
echo "準備完了!"