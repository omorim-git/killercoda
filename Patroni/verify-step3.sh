#!/bin/bash
set -euo pipefail

LAB_ASSET_DIR="/root/kc-patroni-lab"
source "$LAB_ASSET_DIR/lib.sh"

issues=()

if [[ "$(get_ns_mtu "$STANDBY_NS")" != "9000" ]]; then
  issues+=("Standby 側の MTU が 9000 に戻っていません。")
fi

if [[ "$(get_host_mtu "$VETH_STANDBY")" != "9000" ]]; then
  issues+=("Standby 側 veth の MTU が 9000 に戻っていません。")
fi

if qdisc_has_netem "$PRIMARY_NS"; then
  issues+=("Primary 側の netem が残っています。")
fi

if qdisc_has_netem "$STANDBY_NS"; then
  issues+=("Standby 側の netem が残っています。")
fi

if ! ns_exec "$CLIENT_NS" ping -M do -s 8972 -c 1 -W 1 "$STANDBY_IP" >/dev/null 2>&1; then
  issues+=("Jumbo ping がまだ通りません。")
fi

sync_state="$(psql_primary -d postgres -Atqc "select coalesce((select sync_state from pg_stat_replication order by application_name limit 1), '')" 2>/dev/null || true)"
if [[ "$sync_state" != "sync" ]]; then
  issues+=("同期レプリケーションが sync 状態ではありません。")
fi

if (( ${#issues[@]} > 0 )); then
  printf '%s\n' "${issues[@]}"
  exit 1
fi

echo "性能復旧条件を満たしています。"
