#!/bin/bash
set -euo pipefail

SITE_ROOT="/var/www/demo"
SRC_BASE="/opt/kc-assets"
SRC_V2="${SRC_BASE}/v2"

echo "[INFO] Deploying v2 assets from ${SRC_V2} ..."

if [ ! -d "${SRC_V2}" ]; then
  echo "[ERROR] Source not found: ${SRC_V2}"
  exit 1
fi
if [ ! -d "${SITE_ROOT}" ]; then
  echo "[ERROR] Site root not found: ${SITE_ROOT} (Run setup-env.sh first)"
  exit 1
fi

# index.html が v2 にある場合は差し替え、なければスキップ
if [ -f "${SRC_V2}/index.html" ]; then
  echo "[INFO] Replacing index.html ..."
  sudo install -m 0644 "${SRC_V2}/index.html" "${SITE_ROOT}/index.html"
fi

# assets (style.css / app.js) を上書き
if [ -d "${SRC_V2}/assets" ]; then
  echo "[INFO] Syncing assets/ ..."
  sudo rsync -a "${SRC_V2}/assets/" "${SITE_ROOT}/assets/"
fi

# Nginx 設定はそのまま。整合性チェックのみ。
echo "[INFO] Testing Nginx config..."
sudo nginx -t
echo "[INFO] Reloading Nginx..."
sudo systemctl reload nginx

echo "[INFO] v2 deployed."
echo "Open the site and try: normal reload (should still show old assets due to strong cache),"
echo "then hard reload (Ctrl+Shift+R / Cmd+Shift+R) to see v2 on screen."
