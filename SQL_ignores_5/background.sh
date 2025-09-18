#!/bin/bash
echo "[INFO] Updating apt sources to use mirrors.edge.kernel.org..."

# バックアップを保存
sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak.$(date +%s)

# ubuntu.sources を置き換え
sudo sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirrors.iitd.ac.in/ubuntu|g' \
    /etc/apt/sources.list.d/ubuntu.sources


# ====== 設定 ======
DB_NAME="${DB_NAME:-data_db}"
DB_USER="${DB_USER:-postgres_user}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

apt update && apt install -y postgresql > /dev/null 2>&1

systemctl start postgresql
sudo -u postgres createuser postgres_user --createdb
sudo -u postgres psql -c "ALTER USER postgres_user WITH PASSWORD 'postgres_pass';"
systemctl restart postgresql

# パスワードを PGPASSWORD に設定
PGPASS_FILE="$HOME/.pgpass"
LINE="localhost:5432:*:postgres_user:postgres_pass"

if ! grep -qF "$LINE" "$PGPASS_FILE" 2>/dev/null; then
  echo "$LINE" >> "$PGPASS_FILE"
  chmod 600 "$PGPASS_FILE"
  echo "Added credentials to $PGPASS_FILE"
else
  echo ".pgpass already contains the entry"
fi

PSQL_BASE=(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -v ON_ERROR_STOP=1 -X -q)
"${PSQL_BASE[@]}" -d postgres -c "CREATE DATABASE data_db;"

# 準備完了表示
touch /tmp/background-finished