#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "== Nodes =="
kubectl get nodes -o wide
echo

echo "== SUT =="
echo "api url=$(api_url)"
echo "api pod=$(api_pod_name 2>/dev/null || echo missing)"
echo "api node=$(api_pod_node 2>/dev/null || echo unknown)"
if api_healthy 2>/dev/null; then
  echo "api health=ok"
else
  echo "api health=failed"
fi
echo

echo "== k6 Runner Placement =="
echo "worker node=$(worker_node)"
kubectl get jobs -n "$K8S_NAMESPACE" -o wide 2>/dev/null || true
echo

echo "== Host / Service Summary =="
echo "update_state=$(update_state)"
latest_results_count="$(find "${LAB_HOME_DIR}/results" -maxdepth 1 -type f -name '*.log' 2>/dev/null | wc -l)"
echo "latest_results=${latest_results_count:-0}"
