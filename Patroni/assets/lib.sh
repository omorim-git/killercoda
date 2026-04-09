#!/usr/bin/env bash
set -euo pipefail

LAB_NAME="kc-patroni-lab"
LAB_RUNTIME_DIR="/var/lib/${LAB_NAME}"
LAB_CONF_DIR="/etc/${LAB_NAME}"
LAB_HOME_DIR="${HOME}/kc-patroni-lab"

PRIMARY_NS="kc-primary"
STANDBY_NS="kc-standby"
ETCD_NS="kc-etcd"
CLIENT_NS="kc-client"

PRIMARY_IP="10.66.0.11"
STANDBY_IP="10.66.0.12"
ETCD_IP="10.66.0.13"
CLIENT_IP="10.66.0.14"
BRIDGE_IP="10.66.0.1/24"

BRIDGE_DEV="kcbr0"
VETH_PRIMARY="veth-primary"
VETH_STANDBY="veth-standby"
VETH_ETCD="veth-etcd"
VETH_CLIENT="veth-client"

SUPER_USER="postgres"
SUPER_PASSWORD="postgrespass"
APP_USER="app"
APP_PASSWORD="apppass"
BENCH_DB="benchdb"

ETCDCTL_ENDPOINT="http://${ETCD_IP}:2379"

run_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

ns_exec() {
  local ns="$1"
  shift
  run_root ip netns exec "$ns" "$@"
}

ns_bash() {
  local ns="$1"
  shift
  run_root ip netns exec "$ns" /bin/bash -lc "$*"
}

pg_major() {
  cat "${LAB_RUNTIME_DIR}/pg_major"
}

pg_bin_dir() {
  printf '/usr/lib/postgresql/%s/bin' "$(pg_major)"
}

psql_primary() {
  ns_exec "$PRIMARY_NS" env PGPASSWORD="$SUPER_PASSWORD" psql -h "$PRIMARY_IP" -p 5432 -U "$SUPER_USER" "$@"
}

qdisc_has_netem() {
  local ns="$1"
  ns_exec "$ns" tc qdisc show dev eth0 | grep -q 'netem'
}

get_ns_mtu() {
  local ns="$1"
  ns_exec "$ns" ip -o link show dev eth0 | awk '{for (i = 1; i <= NF; i++) if ($i == "mtu") {print $(i + 1); exit}}'
}

get_host_mtu() {
  local dev="$1"
  run_root ip -o link show dev "$dev" | awk '{for (i = 1; i <= NF; i++) if ($i == "mtu") {print $(i + 1); exit}}'
}

firewalld_state() {
  if run_root systemctl is-active --quiet firewalld; then
    echo "active"
  else
    echo "inactive"
  fi
}
