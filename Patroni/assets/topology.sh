#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

printf '%-14s %-30s %s\n' "resource" "role" "location"
printf '%-14s %-30s %s\n' "$(controlplane_node)" "APIとKubernetes管理機能" "$(controlplane_ip)"
printf '%-14s %-30s %s\n' "$(worker_node)" "負荷試験ツールk6" "$(worker_ip)"
printf '%-14s %-30s %s\n' "tat-api" "調査対象のHTTP API" "$(api_url)"

echo
echo "確認例:"
echo "  kubectl get pods -n ${K8S_NAMESPACE} -o wide"
echo "  kubectl describe node $(controlplane_node)"
echo "  kubectl describe node $(worker_node)"
