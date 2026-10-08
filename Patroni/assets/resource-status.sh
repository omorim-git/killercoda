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
  mem_line="$(LC_ALL=C free -m | awk '/^Mem:/ {printf "メモリ: 使用=%s MiB / 利用可能=%s MiB / 合計=%s MiB", $3, $7, $2}')"

  echo "== Resource Snapshot @ ${now} =="
  printf 'summary: '
  printf '%s\n' "$vmstat_line" | awk '{printf "CPU: アプリ=%s%% OS=%s%% 空き=%s%% I/O待ち=%s%% 仮想CPU待ち=%s%% | 実行待ち=%s / I/O待ちタスク=%s | ディスク: 読込=%s 書込=%s KiB/s | ", $13,$14,$15,$16,$17,$1,$2,$9,$10}'
  echo "$mem_line"
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
  echo "vmstat の列: r=実行待ち b=I/O待ち swpd=スワップ使用 free=空き buff=バッファ cache=キャッシュ"
  echo "si/so=スワップ入出力 bi/bo=ディスク読書(KiB/s) in=割込み cs=切替(回/秒)"
  echo "us=アプリ sy=OS id=空き wa=I/O待ち st=仮想CPU待ち(%)。末尾に追加列が出る場合があります。"
  LC_ALL=C vmstat 1 2
  free -m
  echo

  echo "== Top Processes by CPU =="
  ps -eo pid,comm,%cpu,%mem,rss --sort=-%cpu | sed -n '1,8p'
  echo

  echo "== Top Processes by Memory =="
  ps -eo pid,comm,%cpu,%mem,rss --sort=-%mem | sed -n '1,8p'
  echo

  echo "== Disk / Pressure Signals =="
  df -h /
  if command -v iostat >/dev/null 2>&1; then
    iostat -xz 1 2 | tail -n +1
  else
    echo "iostat unavailable; showing vmstat io columns only"
    LC_ALL=C vmstat 1 2
  fi
  echo
}

for iteration in $(seq 1 "$snapshot_count"); do
  print_snapshot
  if (( iteration < snapshot_count )); then
    sleep "$interval_seconds"
  fi
done
