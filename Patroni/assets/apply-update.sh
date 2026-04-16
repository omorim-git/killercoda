#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

log() {
  echo "[update] $*"
}

if [[ -f "${LAB_RUNTIME_DIR}/update-applied" ]]; then
  log "Update state has already been applied"
  exit 0
fi

log "Enabling firewalld"
systemctl enable firewalld >/dev/null 2>&1 || true
systemctl start firewalld

if ! firewall-cmd --permanent --get-zones | tr ' ' '\n' | grep -qx 'kc-lab'; then
  firewall-cmd --permanent --new-zone=kc-lab >/dev/null
fi

firewall-cmd --permanent --zone=kc-lab --add-interface="$BRIDGE_DEV" >/dev/null 2>&1 || true
for port in 2379/tcp 2380/tcp 5432/tcp 8008/tcp; do
  firewall-cmd --permanent --zone=kc-lab --add-port="$port" >/dev/null
done
firewall-cmd --reload >/dev/null

log "Reducing standby MTU"
ip link set dev "$VETH_STANDBY" mtu 1500
ip -n "$STANDBY_NS" link set dev eth0 mtu 1500

log "Applying netem delay and loss"
ns_exec "$PRIMARY_NS" tc qdisc replace dev eth0 root netem delay 30ms loss 2%
ns_exec "$STANDBY_NS" tc qdisc replace dev eth0 root netem delay 30ms loss 2%

touch "${LAB_RUNTIME_DIR}/update-applied"
log "Update state has been applied"
