#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "== Kubernetes nodes =="
kubectl get nodes -o wide
echo
echo "== API and database pods =="
kctl get pods -o wide
echo
echo "== Service endpoint for the current database primary =="
kctl get endpoints "$DB_SERVICE" -o wide 2>/dev/null || true
echo
echo "== Patroni / PostgreSQL replication =="
primary="$(db_primary_pod_name 2>/dev/null || true)"
if [[ -n "$primary" ]]; then
  kctl exec "$primary" -- psql -U postgres -d "$DB_NAME" -P pager=off -c \
    "SELECT application_name, client_addr, state, sync_state, write_lag, flush_lag, replay_lag FROM pg_stat_replication;" 2>/dev/null || true
  kctl exec "$primary" -- psql -U postgres -d "$DB_NAME" -Atqc \
    "SELECT 'synchronous_commit='||current_setting('synchronous_commit')||E'\nsynchronous_standby_names='||current_setting('synchronous_standby_names');" 2>/dev/null || true
else
  echo "primary pod not found"
fi
echo
echo "== API =="
echo "url=$(api_url)"
echo "pod=$(api_pod_name 2>/dev/null || echo missing) node=$(api_pod_node 2>/dev/null || echo unknown)"
if api_healthy 2>/dev/null; then echo "health=ok (database query succeeded)"; else echo "health=failed"; fi
echo
echo "== Load test jobs =="
kctl get jobs -o wide 2>/dev/null || true
echo
