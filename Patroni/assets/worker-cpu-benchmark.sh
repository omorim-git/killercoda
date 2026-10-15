#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

rate="${1:-50}"
if [[ ! "$rate" =~ ^[0-9]+$ ]] || (( rate < 1 )); then
  echo "Usage: $0 [positive-rate]" >&2
  exit 2
fi

results_dir="${LAB_HOME_DIR}/results"
mkdir -p "$results_dir"
stamp="$(date +%Y%m%d-%H%M%S)"
worker_log="${results_dir}/worker-after-update-${stamp}.procstat.log"

ssh node01 'while :; do printf "TIME "; date -Is; awk '\''/^cpu([0-9]+)? / {print}'\'' /proc/stat; sleep 1; done' >"$worker_log" 2>&1 &
monitor_pid=$!
cleanup() {
  kill "$monitor_pid" 2>/dev/null || true
  wait "$monitor_pid" 2>/dev/null || true
}
trap cleanup EXIT

sleep 2
set +e
"${SCRIPT_DIR}/benchmark.sh" after-update-worker "$rate"
benchmark_status=$?
set -e

printf 'worker_cpu_log: %s\n' "$worker_log"
exit "$benchmark_status"
