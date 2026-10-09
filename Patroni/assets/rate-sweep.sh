#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

label_prefix="${1:-sweep}"
shift || true

if (( $# == 0 )); then
  rates=(30 40 50 75 100 150 200)
else
  rates=("$@")
fi

printf '%-14s %-8s %-12s %-12s %-12s %-10s %-12s %-12s\n' \
  "label" "rate" "avg" "p95" "failed" "dropped" "reqs" "job_status"

for rate in "${rates[@]}"; do
  run_label="${label_prefix}-${rate}"
  job_status="ok"
  if ! "${BASH_SOURCE%/*}/benchmark.sh" "$run_label" "$rate" >/tmp/"${run_label}".out 2>&1; then
    job_status="k6-failed"
  fi

  logfile="$(find_latest_result "$run_label")"
  if [[ -z "$logfile" ]]; then
    job_status="no-result"
    echo "[rate-sweep] rate=${rate}: no result log; benchmark output: /tmp/${run_label}.out" >&2
    tail -n 30 "/tmp/${run_label}.out" >&2 || true
    printf '%-14s %-8s %-12s %-12s %-12s %-10s %-12s %-12s\n' \
      "$run_label" "$rate" "n/a" "n/a" "n/a" "n/a" "n/a" "$job_status"
    continue
  fi

  avg="$(extract_k6_stat "$logfile" 'http_req_duration' 'avg')"
  p95="$(extract_k6_stat "$logfile" 'http_req_duration' 'p(95)')"
  failed="$(extract_k6_failed_rate "$logfile")"
  dropped="$(extract_k6_dropped_iterations "$logfile")"
  reqs_rate="$(extract_k6_http_reqs_rate "$logfile")"
  resource_overview="$(awk '/^resource_summary:/' "$logfile")"
  resource_graph="$(awk '/^resource_graph:/' "$logfile")"

  printf '%-14s %-8s %-12s %-12s %-12s %-10s %-12s %-12s\n' \
    "$run_label" \
    "$rate" \
    "${avg:-n/a}" \
    "${p95:-n/a}" \
    "${failed:-0.00%}" \
    "${dropped:-0}" \
    "${reqs_rate:-n/a}" \
    "$job_status"
  printf '%s\n' "$resource_overview"
  if [[ -n "$resource_graph" ]]; then
    printf '%s\n' "$resource_graph"
  fi
  printf '  保存先: %s\n' "$logfile"
done
