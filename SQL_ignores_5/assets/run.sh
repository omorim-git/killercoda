#!/usr/bin/env bash
set -euo pipefail

# ====== 設定 ======
DB_NAME="${DB_NAME:-data_db}"
DB_USER="${DB_USER:-postgres_user}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

# psql 共通オプション
PSQL_BASE=(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -v ON_ERROR_STOP=1 -X -q)

echo -n "Update Name..."
"${PSQL_BASE[@]}" -d "${DB_NAME}" -c "UPDATE users SET name = 'Updated_' || name WHERE id BETWEEN '0' AND '24';" &
"${PSQL_BASE[@]}" -d "${DB_NAME}" -c "UPDATE users SET name = 'Updated_' || name WHERE id BETWEEN '25' AND '49';" &
"${PSQL_BASE[@]}" -d "${DB_NAME}" -c "UPDATE users SET name = 'Updated_' || name WHERE id BETWEEN '50' AND '74';" &
"${PSQL_BASE[@]}" -d "${DB_NAME}" -c "UPDATE users SET name = 'Updated_' || name WHERE id BETWEEN '75' AND '99';" &

wait

echo " Finished!"
