#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sync_commit="$(psql_primary -d postgres -Atqc 'show synchronous_commit;' 2>/dev/null || echo unknown)"
sync_standby_names="$(psql_primary -d postgres -Atqc 'show synchronous_standby_names;' 2>/dev/null || echo unknown)"
replication_state="$(psql_primary -d postgres -Atqc "select application_name || ':' || state || ':' || sync_state from pg_stat_replication order by application_name;" 2>/dev/null || echo unknown)"
primary_mtu="$(get_ns_mtu "$PRIMARY_NS" 2>/dev/null || echo unknown)"
standby_mtu="$(get_ns_mtu "$STANDBY_NS" 2>/dev/null || echo unknown)"
primary_qdisc="$(ns_exec "$PRIMARY_NS" tc qdisc show dev eth0 2>/dev/null | tr '\n' ' ' || echo unknown)"
standby_qdisc="$(ns_exec "$STANDBY_NS" tc qdisc show dev eth0 2>/dev/null | tr '\n' ' ' || echo unknown)"

echo "== Patroni cluster =="
patronictl -c "${LAB_CONF_DIR}/patroni-primary.yml" list || true
echo

echo "== Sync settings =="
echo "synchronous_commit=${sync_commit}"
echo "synchronous_standby_names=${sync_standby_names}"
echo "replication=${replication_state}"
echo

echo "== Network =="
echo "firewalld=$(firewalld_state)"
echo "primary mtu=${primary_mtu}"
echo "standby mtu=${standby_mtu}"
echo "primary qdisc=${primary_qdisc}"
echo "standby qdisc=${standby_qdisc}"
