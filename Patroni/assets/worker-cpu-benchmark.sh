#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if (( $# == 0 )); then
  rates=(30 40 50 75 100)
else
  rates=("$@")
fi
for rate in "${rates[@]}"; do
  if [[ ! "$rate" =~ ^[0-9]+$ ]] || (( rate < 1 )); then
    echo "Usage: $0 [positive-rate ...]" >&2
    exit 2
  fi
done

worker="$(worker_node)"
mkdir -p "${LAB_HOME_DIR}/results" "$ARTIFACT_DIR"
overall_status=0

for rate in "${rates[@]}"; do
  label="after-update-worker-${rate}"
  stamp="$(date +%Y%m%d-%H%M%S)"
  worker_log="${LAB_HOME_DIR}/results/worker-${label}-${stamp}.procstat.log"
  worker_summary="${LAB_HOME_DIR}/results/worker-${label}-${stamp}.summary.txt"
  worker_graph="${LAB_HOME_DIR}/results/${stamp}-${label}-node01-cpu.svg"
  published_graph="${ARTIFACT_DIR}/$(basename "$worker_graph")"
  remote_monitor_pid=""

  cleanup_monitor() {
    if [[ -n "$remote_monitor_pid" ]]; then
      kill "$remote_monitor_pid" 2>/dev/null || true
      wait "$remote_monitor_pid" 2>/dev/null || true
      remote_monitor_pid=""
    fi
  }
  trap cleanup_monitor EXIT

  echo "[worker-cpu] rate=${rate}/s; sampling worker=${worker} via ssh ${worker}"
  ssh "$worker" 'printf "HOSTNAME "; hostname -s; while :; do printf "TIME "; date +%s.%N; grep "^cpu" /proc/stat; sleep 1; done' >"$worker_log" 2>&1 &
  remote_monitor_pid=$!
  sleep 2

  benchmark_status=0
  "${SCRIPT_DIR}/benchmark.sh" "$label" "$rate" || benchmark_status=$?
  cleanup_monitor

  result_log="$(find_latest_result "$label")"
  if [[ -z "$result_log" ]]; then
    echo "[worker-cpu] benchmark log not found for ${label}" >&2
    overall_status=1
    continue
  fi

  if ! python3 "${SCRIPT_DIR}/collect-worker-cpu.py" "$worker_log" "$result_log" "$worker_graph" "$worker" >"$worker_summary"; then
    echo "[worker-cpu] failed to validate worker source or build CPU graph for ${label}" >&2
    overall_status=1
    continue
  fi
  cp "$worker_graph" "$published_graph"
  cat "$worker_summary"
  echo "${worker} CPU graph: $published_graph"
  echo "node01 CPU samples: $worker_log"
  if (( benchmark_status != 0 )); then
    overall_status=1
  fi
done

trap - EXIT
exit "$overall_status"
