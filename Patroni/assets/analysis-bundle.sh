#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

results_dir="${LAB_HOME_DIR}/results"
mkdir -p "$results_dir"

timestamp="$(date +%Y%m%d-%H%M%S)"
outfile="${results_dir}/${timestamp}-analysis-bundle.txt"
published_file="${ARTIFACT_DIR}/$(basename "$outfile")"

ensure_artifact_server || true

latest_logs() {
  find "$results_dir" -maxdepth 1 -name '*.log' ! -name '*.resources.log' \
    ! -name 'worker-*.vmstat.log' -type f | sort
}

latest_worker_logs() {
  find "$results_dir" -maxdepth 1 -name 'worker-*.vmstat.log' -type f | sort
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

  echo "== API pod details =="
  kubectl describe pod -n "$K8S_NAMESPACE" -l app=tat-api || true
  echo

  echo "== API previous container logs =="
  api_pod="$(api_pod_name 2>/dev/null || true)"
  if [[ -n "$api_pod" ]]; then
    kubectl logs -n "$K8S_NAMESPACE" "$api_pod" --previous 2>&1 || true
  else
    echo "API Pod not found"
  fi
  echo

  echo "== Database pod descriptions =="
  kubectl describe pod -n "$K8S_NAMESPACE" -l "cluster-name=${DB_CLUSTER}" || true
  echo

  echo "== Database container logs =="
  for pod in $(kctl get pods -l "cluster-name=${DB_CLUSTER}" -o name 2>/dev/null); do
    echo "--- ${pod} ---"
    kctl logs "$pod" --all-containers --tail=120 2>&1 || true
  done
  echo

  echo "== Standby node current CPU snapshot (not load-window average) =="
  standby_node="$(db_standby_node 2>/dev/null || true)"
  if [[ -n "$standby_node" ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=3 "$standby_node" 'vmstat 1 3; ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 12' 2>&1 || true
  else
    echo "Standby node not found"
  fi
  echo

  echo "== Worker CPU samples captured during benchmark =="
  worker_logs="$(latest_worker_logs)"
  if [[ -n "$worker_logs" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      echo "--- ${file} ---"
      cat "$file" || true
    done <<<"$worker_logs"
  else
    echo "No worker vmstat logs found"
  fi
  echo

  echo "== Recent namespace events =="
  kubectl get events -n "$K8S_NAMESPACE" --sort-by=.lastTimestamp | tail -n 40 || true
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
} >"$outfile" 2>&1

cp "$outfile" "$published_file"

echo "Saved: $outfile"
echo "Published: $published_file"
echo "ブラウザーのファイル一覧から、この .txt ファイルを開いてダウンロードしてください。"
