#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

export DEBIAN_FRONTEND=noninteractive

log() {
  echo "[install] $*"
}

dump_failure_context() {
  local role="$1"
  local ns="$2"
  local log_path="$3"
  local data_dir="$4"

  echo "== ${role} patroni log ==" >&2
  tail -n 200 "$log_path" >&2 2>/dev/null || true

  echo "== ${role} namespace listen sockets ==" >&2
  ip netns exec "$ns" ss -lntp >&2 || true

  echo "== ${role} postgres processes ==" >&2
  ip netns exec "$ns" ps -ef >&2 || true

  echo "== /run/postgresql permissions ==" >&2
  ls -ld /run/postgresql /var/run/postgresql >&2 2>/dev/null || true

  echo "== ${role} data directory ==" >&2
  ls -la "$data_dir" >&2 2>/dev/null || true

  if compgen -G "${data_dir}/log/*" >/dev/null; then
    echo "== ${role} postgres log files ==" >&2
    tail -n 200 "${data_dir}"/log/* >&2 2>/dev/null || true
  fi
}

cleanup_previous() {
  log "Cleaning previous lab state"

  pkill -f "${LAB_CONF_DIR}/patroni-primary.yml" 2>/dev/null || true
  pkill -f "${LAB_CONF_DIR}/patroni-standby.yml" 2>/dev/null || true
  pkill -f "${LAB_RUNTIME_DIR}/etcd-data" 2>/dev/null || true
  sleep 2

  for ns in "$PRIMARY_NS" "$STANDBY_NS" "$ETCD_NS" "$CLIENT_NS"; do
    ip netns del "$ns" 2>/dev/null || true
  done
  ip link del "$BRIDGE_DEV" 2>/dev/null || true

  rm -rf "$LAB_RUNTIME_DIR" "$LAB_CONF_DIR" /var/lib/postgresql/kc-primary /var/lib/postgresql/kc-standby
  mkdir -p "$LAB_RUNTIME_DIR" "$LAB_CONF_DIR"
}

create_ns() {
  local ns="$1"
  local host_if="$2"
  local ip_addr="$3"

  ip netns add "$ns"
  ip link add "$host_if" type veth peer name eth0 netns "$ns"
  ip link set dev "$host_if" mtu 9000
  ip link set dev "$host_if" master "$BRIDGE_DEV"
  ip link set dev "$host_if" up

  ip -n "$ns" link set dev lo up
  ip -n "$ns" link set dev eth0 mtu 9000
  ip -n "$ns" addr add "$ip_addr/24" dev eth0
  ip -n "$ns" link set dev eth0 up
  ip -n "$ns" route add default via "${BRIDGE_IP%/*}"
}

write_patroni_config() {
  local name="$1"
  local ip_addr="$2"
  local cfg_path="$3"
  local data_dir="$4"
  local pg_major_value="$5"

  cat >"$cfg_path" <<EOF
scope: kc-sync-lab
namespace: /service/
name: ${name}

restapi:
  listen: ${ip_addr}:8008
  connect_address: ${ip_addr}:8008

etcd:
  hosts: ${ETCD_IP}:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    synchronous_mode: true
    synchronous_mode_strict: true
    postgresql:
      use_pg_rewind: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_connections: 50
        max_wal_senders: 10
        max_replication_slots: 10
        wal_keep_size: 256MB
        shared_buffers: 32MB
        synchronous_commit: "on"
  initdb:
    - encoding: UTF8
    - data-checksums
  users:
    ${APP_USER}:
      password: ${APP_PASSWORD}
      options:
        - createdb
        - createrole
  pg_hba:
    - host all all 10.66.0.0/24 md5
    - host replication replicator 10.66.0.0/24 md5
    - host all all 127.0.0.1/32 trust

postgresql:
  listen: ${ip_addr}:5432
  connect_address: ${ip_addr}:5432
  data_dir: ${data_dir}
  bin_dir: /usr/lib/postgresql/${pg_major_value}/bin
  pgpass: /var/lib/postgresql/.pgpass
  authentication:
    replication:
      username: replicator
      password: replpass
    superuser:
      username: postgres
      password: ${SUPER_PASSWORD}
    rewind:
      username: rewind
      password: rewindpass
  parameters:
    unix_socket_directories: /var/run/postgresql
    logging_collector: "on"
    log_directory: log
    log_filename: postgresql-%a.log

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF
}

start_etcd() {
  log "Starting etcd"
  nohup ip netns exec "$ETCD_NS" \
    etcd \
      --name kc-etcd \
      --data-dir "${LAB_RUNTIME_DIR}/etcd-data" \
      --enable-v2=true \
      --listen-client-urls "http://${ETCD_IP}:2379" \
      --advertise-client-urls "http://${ETCD_IP}:2379" \
      --listen-peer-urls "http://${ETCD_IP}:2380" \
      --initial-advertise-peer-urls "http://${ETCD_IP}:2380" \
      --initial-cluster "kc-etcd=http://${ETCD_IP}:2380" \
      --initial-cluster-state new \
      >"${LAB_RUNTIME_DIR}/etcd.log" 2>&1 &
  echo $! >"${LAB_RUNTIME_DIR}/etcd.pid"

  for _ in $(seq 1 30); do
    if ETCDCTL_API=3 etcdctl --endpoints="$ETCDCTL_ENDPOINT" endpoint health >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  echo "etcd did not become healthy" >&2
  exit 1
}

start_patroni() {
  local ns="$1"
  local cfg_path="$2"
  local log_path="$3"
  local pid_path="$4"
  local path_env="$5"

  nohup ip netns exec "$ns" \
    env HOME=/var/lib/postgresql PATH="$path_env" PYTHONUNBUFFERED=1 \
    runuser -u postgres -- patroni "$cfg_path" \
    >"$log_path" 2>&1 &
  echo $! >"$pid_path"
}

wait_for_primary() {
  log "Waiting for primary"
  for _ in $(seq 1 60); do
    if psql_primary -d postgres -Atqc "select pg_is_in_recovery()" 2>/dev/null | grep -qx 'f'; then
      return 0
    fi
    sleep 2
  done

  dump_failure_context "primary" "$PRIMARY_NS" "${LAB_RUNTIME_DIR}/patroni-primary.log" "/var/lib/postgresql/kc-primary"
  echo "primary did not become ready" >&2
  exit 1
}

wait_for_sync_standby() {
  log "Waiting for synchronous standby"
  for _ in $(seq 1 90); do
    if psql_primary -d postgres -Atqc "select coalesce((select sync_state from pg_stat_replication order by application_name limit 1), '')" 2>/dev/null | grep -qx 'sync'; then
      return 0
    fi
    sleep 2
  done

  dump_failure_context "standby" "$STANDBY_NS" "${LAB_RUNTIME_DIR}/patroni-standby.log" "/var/lib/postgresql/kc-standby"
  echo "standby did not reach sync state" >&2
  exit 1
}

initialize_benchmark_db() {
  log "Initializing pgbench database"
  ns_exec "$CLIENT_NS" env PGPASSWORD="$APP_PASSWORD" dropdb --if-exists -h "$PRIMARY_IP" -p 5432 -U "$APP_USER" "$BENCH_DB" >/dev/null 2>&1 || true
  ns_exec "$CLIENT_NS" env PGPASSWORD="$APP_PASSWORD" createdb -h "$PRIMARY_IP" -p 5432 -U "$APP_USER" "$BENCH_DB"
  ns_exec "$CLIENT_NS" env PGPASSWORD="$APP_PASSWORD" \
    pgbench -i -s 10 -h "$PRIMARY_IP" -p 5432 -U "$APP_USER" "$BENCH_DB" \
    >"${LAB_RUNTIME_DIR}/pgbench-init.log" 2>&1
}

log "Installing packages"
apt-get update
apt-get install -y --no-install-recommends \
  iproute2 \
  iputils-ping \
  net-tools \
  jq \
  postgresql \
  postgresql-contrib \
  patroni \
  etcd-server \
  etcd-client \
  firewalld \
  procps

log "Stopping default services"
systemctl stop postgresql 2>/dev/null || true
systemctl disable postgresql 2>/dev/null || true
systemctl stop patroni 2>/dev/null || true
systemctl disable patroni 2>/dev/null || true
systemctl stop etcd 2>/dev/null || true
systemctl disable etcd 2>/dev/null || true
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true

if command -v pg_lsclusters >/dev/null 2>&1; then
  while read -r ver name _; do
    [[ -n "${ver:-}" ]] || continue
    pg_dropcluster --stop "$ver" "$name" 2>/dev/null || true
  done < <(pg_lsclusters --no-header 2>/dev/null || true)
fi

cleanup_previous

PG_MAJOR_VALUE="$(psql -V | awk '{print $3}' | cut -d. -f1)"
echo "$PG_MAJOR_VALUE" >"${LAB_RUNTIME_DIR}/pg_major"
PATH_ENV="/usr/lib/postgresql/${PG_MAJOR_VALUE}/bin:/usr/sbin:/usr/bin:/sbin:/bin"

log "Creating bridge and namespaces"
ip link add "$BRIDGE_DEV" type bridge
ip link set dev "$BRIDGE_DEV" mtu 9000
ip addr add "$BRIDGE_IP" dev "$BRIDGE_DEV"
ip link set dev "$BRIDGE_DEV" up

create_ns "$PRIMARY_NS" "$VETH_PRIMARY" "$PRIMARY_IP"
create_ns "$STANDBY_NS" "$VETH_STANDBY" "$STANDBY_IP"
create_ns "$ETCD_NS" "$VETH_ETCD" "$ETCD_IP"
create_ns "$CLIENT_NS" "$VETH_CLIENT" "$CLIENT_IP"

log "Preparing directories and configs"
install -d -m 0755 "$LAB_CONF_DIR"
install -d -o postgres -g postgres -m 0700 /var/lib/postgresql/kc-primary /var/lib/postgresql/kc-standby
install -d -o postgres -g postgres -m 2775 /run/postgresql

write_patroni_config "primary" "$PRIMARY_IP" "${LAB_CONF_DIR}/patroni-primary.yml" "/var/lib/postgresql/kc-primary" "$PG_MAJOR_VALUE"
write_patroni_config "standby" "$STANDBY_IP" "${LAB_CONF_DIR}/patroni-standby.yml" "/var/lib/postgresql/kc-standby" "$PG_MAJOR_VALUE"

chown -R postgres:postgres "$LAB_CONF_DIR" /var/lib/postgresql/kc-primary /var/lib/postgresql/kc-standby

rm -f "${LAB_RUNTIME_DIR}/update-applied"

start_etcd

log "Starting Patroni primary"
start_patroni "$PRIMARY_NS" "${LAB_CONF_DIR}/patroni-primary.yml" "${LAB_RUNTIME_DIR}/patroni-primary.log" "${LAB_RUNTIME_DIR}/patroni-primary.pid" "$PATH_ENV"
wait_for_primary

log "Starting Patroni standby"
start_patroni "$STANDBY_NS" "${LAB_CONF_DIR}/patroni-standby.yml" "${LAB_RUNTIME_DIR}/patroni-standby.log" "${LAB_RUNTIME_DIR}/patroni-standby.pid" "$PATH_ENV"
wait_for_sync_standby

initialize_benchmark_db

log "Running smoke benchmark"
ns_exec "$CLIENT_NS" env PGPASSWORD="$APP_PASSWORD" \
  pgbench -h "$PRIMARY_IP" -p 5432 -U "$APP_USER" -d "$BENCH_DB" -N -T 5 -c 4 -j 2 \
  >"${LAB_RUNTIME_DIR}/smoke.log" 2>&1

log "Lab is ready"
