#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

results_dir="${LAB_HOME_DIR}/results"
mkdir -p "$results_dir"

timestamp="$(date +%Y%m%d-%H%M%S)"
outfile="${results_dir}/${timestamp}-analysis-bundle.txt"

latest_logs() {
  find "$results_dir" -maxdepth 1 -name '*.log' ! -name '*.resources.log' -type f | sort
}

{
  echo "== cluster-status =="
  "${SCRIPT_DIR}/cluster-status.sh" || true
  echo

  echo "== compare-results =="
  "${SCRIPT_DIR}/compare-results.sh" || true
  echo

  echo "== 現在の状態（負荷中の値ではありません） =="
  "${SCRIPT_DIR}/resource-status.sh" 1 5 || true
  echo

  echo "== kubectl get nodes -o wide =="
  kubectl get nodes -o wide || true
  echo

  echo "== kubectl get pods -n ${K8S_NAMESPACE} -o wide =="
  kubectl get pods -n "$K8S_NAMESPACE" -o wide || true
  echo

  echo "== kubectl get jobs -n ${K8S_NAMESPACE} -o wide =="
  kubectl get jobs -n "$K8S_NAMESPACE" -o wide || true
  echo

  echo "== host sockets =="
  ss -s || true
  echo

  echo "== top cpu processes =="
  ps -eo pid,comm,%cpu,%mem,rss --sort=-%cpu | head -n 10 || true
  echo

  echo "== latest benchmark logs =="
  for file in $(latest_logs); do
    echo "--- ${file} ---"
    cat "$file" || true
    samples="${file%.log}.resources.jsonl"
    if [[ -f "$samples" ]]; then
      echo "--- 時刻付きリソース記録: $samples ---"
      cat "$samples"
      echo "--- 採取エラー（空ならエラーなし） ---"
      cat "${samples}.errors" 2>/dev/null || true
    fi
    echo
  done
} | tee "$outfile"

echo "Saved: $outfile"
