#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

cp_node="$(controlplane_node)"
worker="$(worker_node)"
primary="$(db_primary_pod_name 2>/dev/null || true)"
standby="$(db_standby_pod_name 2>/dev/null || true)"

echo "k6 runner (client) -> HTTP API -> PostgreSQL Primary -> synchronous WAL -> PostgreSQL Standby"
printf '%-16s %-34s %s\n' "NODE" "ROLE" "IP"
printf '%-16s %-34s %s\n' "$cp_node" "API + PostgreSQL Primary" "$(controlplane_ip)"
printf '%-16s %-34s %s\n' "$worker" "PostgreSQL Standby + k6 runner" "$(worker_ip)"
printf '\nAPI: %s\n' "$(api_url)"
printf 'Primary pod: %s\n' "${primary:-starting}"
printf 'Standby pod: %s\n' "${standby:-starting}"
echo
echo "注意: 2ノード環境の制約で、Standbyとk6 runnerは同じworker上に配置されます。"
echo "APIリクエストごとにDBへINSERTしてCOMMITし、同期レプリカの応答を待ちます。"
echo
echo "確認例:"
echo "  kubectl get pods -n ${K8S_NAMESPACE} -o wide"
echo "  ~/kc-patroni-lab/cluster-status.sh"
