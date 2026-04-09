#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

cat <<EOF
namespace     role                        ip
${CLIENT_NS}   pgbench client               ${CLIENT_IP}
${PRIMARY_NS}  PostgreSQL + Patroni leader  ${PRIMARY_IP}
${STANDBY_NS}  PostgreSQL + Patroni standby ${STANDBY_IP}
${ETCD_NS}     etcd                         ${ETCD_IP}

bridge: ${BRIDGE_DEV} (${BRIDGE_IP})

namespace に入る例:
  sudo ip netns exec ${PRIMARY_NS} bash
  sudo ip netns exec ${STANDBY_NS} bash
  sudo ip netns exec ${CLIENT_NS} bash
EOF
