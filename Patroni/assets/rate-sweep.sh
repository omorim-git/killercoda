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

printf '%-14s %-8s %-12s %-12s %-12s %-10s %-12s\n' \
  "label" "rate" "avg" "p95" "failed" "dropped" "reqs"

for rate in "${rates[@]}"; do
  run_label="${label_prefix}-${rate}"
  "${BASH_SOURCE%/*}/benchmark.sh" "$run_label" "$rate" >/tmp/"${run_label}".out 2>&1 || {
    cat /tmp/"${run_label}".out >&2
    echo "benchmark failed for rate=${rate}" >&2
    exit 1
  }

  logfile="$(find_latest_result "$run_label")"
  if [[ -z "$logfile" ]]; then
    echo "missing result log for ${run_label}" >&2
    exit 1
  fi

  avg="$(extract_k6_stat "$logfile" 'http_req_duration' 'avg')"
  p95="$(extract_k6_stat "$logfile" 'http_req_duration' 'p\(95\)')"
  failed="$(extract_k6_failed_rate "$logfile")"
  dropped="$(extract_k6_dropped_iterations "$logfile")"
  reqs_rate="$(extract_k6_http_reqs_rate "$logfile")"
  resource_overview="$("${BASH_SOURCE%/*}/resource-status.sh" 1 5 | awk '/^summary:/ {print; exit}')"

  printf '%-14s %-8s %-12s %-12s %-12s %-10s %-12s\n' \
    "$run_label" \
    "$rate" \
    "${avg:-n/a}" \
    "${p95:-n/a}" \
    "${failed:-0.00%}" \
    "${dropped:-0}" \
    "${reqs_rate:-n/a}"
  printf '  %s\n' "$resource_overview"
done
