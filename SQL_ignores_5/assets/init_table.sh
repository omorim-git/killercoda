#!/usr/bin/env bash
set -euo pipefail

# ====== 設定 ======
DB_NAME="${DB_NAME:-data_db}"
DB_USER="${DB_USER:-postgres_user}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

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

# psql 共通オプション
PSQL_BASE=(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -v ON_ERROR_STOP=1 -X -q)

echo "==> Checking if database '${DB_NAME}' exists..."
if ! "${PSQL_BASE[@]}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  echo "==> Creating database '${DB_NAME}'..."
  "${PSQL_BASE[@]}" -d postgres -c "CREATE DATABASE ${DB_NAME};"
else
  echo "==> Database '${DB_NAME}' already exists. Skipping create."
fi

echo "==> Recreating table 'users' in '${DB_NAME}'..."
# テーブルを作り直し（存在すればDROPしてCREATE）
"${PSQL_BASE[@]}" -d "${DB_NAME}" <<'SQL'
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id   character varying PRIMARY KEY,
  name character varying(100) NOT NULL
);
SQL

echo "==> Inserting sample rows: User0 ... User99"
# 0〜99 を投入（idは文字列、nameは 'User' + 数値）
"${PSQL_BASE[@]}" -d "${DB_NAME}" -c "
INSERT INTO users (id, name)
SELECT gs::text AS id, 'User' || gs::text AS name
FROM generate_series(0, 99) AS gs;
"

echo "==> Done. Row count:"
"${PSQL_BASE[@]}" -d "${DB_NAME}" -c "SELECT COUNT(*) AS users_count FROM users;"

echo "==> First 10 rows preview:"
"${PSQL_BASE[@]}" -d "${DB_NAME}" -c "SELECT * FROM users ORDER BY id::int LIMIT 10;"

