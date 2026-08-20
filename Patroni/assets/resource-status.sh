#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

snapshot_count="${1:-1}"
interval_seconds="${2:-5}"

print_snapshot() {
  local now
  local vmstat_line
  local mem_line

  now="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  vmstat_line="$(vmstat 1 2 | tail -n 1 | tr -s ' ')"
  mem_line="$(free -m | awk '/^Mem:/ {printf "used_mb=%s free_mb=%s available_mb=%s", $3, $4, $7}')"

  echo "== Resource Snapshot @ ${now} =="
  echo "summary: vmstat=${vmstat_line} | ${mem_line}"
  echo

  echo "== Kubernetes Node Metrics =="
  if kubectl top nodes >/dev/null 2>&1; then
    kubectl top nodes
  else
    echo "kubectl top nodes: metrics-server unavailable"
  fi
  echo

  echo "== Kubernetes Pod Metrics =="
  if kubectl top pods -n "$K8S_NAMESPACE" >/dev/null 2>&1; then
    kubectl top pods -n "$K8S_NAMESPACE"
  else
    echo "kubectl top pods: metrics-server unavailable"
  fi
  echo

  echo "== Host CPU / Memory (controlplane) =="
  printf '%s\n' "$vmstat_line"
  free -m
  echo

  echo "== Top Processes by CPU =="
  ps -eo pid,comm,%cpu,%mem,rss --sort=-%cpu | head -n 8
  echo

  echo "== Top Processes by Memory =="
  ps -eo pid,comm,%cpu,%mem,rss --sort=-%mem | head -n 8
  echo

  echo "== Disk / Pressure Signals =="
  df -h /
  if command -v iostat >/dev/null 2>&1; then
    iostat -xz 1 2 | tail -n +1
  else
    echo "iostat unavailable; showing vmstat io columns only"
    vmstat 1 2 | tail -n 1
  fi
  echo
}

for iteration in $(seq 1 "$snapshot_count"); do
  print_snapshot
  if (( iteration < snapshot_count )); then
    sleep "$interval_seconds"
  fi
done
