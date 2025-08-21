#!/usr/bin/env bash
set -euo pipefail

apt update && apt install -y postgresql > /dev/null 2>&1

systemctl start postgresql
sudo -u postgres createuser postgres_user --createdb
sudo -u postgres psql -c "ALTER USER postgres_user WITH PASSWORD 'postgres_pass';"
systemctl restart postgresql

PSQL_BASE=(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -v ON_ERROR_STOP=1 -X -q)
"${PSQL_BASE[@]}" -d postgres -c "CREATE DATABASE mydb;"
