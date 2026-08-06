#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

summary() {
  local file="$1"
  local avg
  local p95
  local failed

  avg="$(extract_k6_stat "$file" 'http_req_duration' 'avg')"
  p95="$(extract_k6_stat "$file" 'http_req_duration' 'p\(95\)')"
  failed="$(extract_k6_failed_rate "$file")"

  printf '%s\n' "file: $file"
  printf '%s\n' "  http_req_duration avg: ${avg:-n/a}"
  printf '%s\n' "  http_req_duration p95: ${p95:-n/a}"
  printf '%s\n' "  http_req_failed: ${failed:-n/a}"
}

mapfile -t files < <(printf '%s\n' "$@" | sed '/^$/d')
if (( ${#files[@]} == 0 )); then
  if [[ ! -d "${LAB_HOME_DIR}/results" ]]; then
    echo "No results directory: ${LAB_HOME_DIR}/results" >&2
    exit 1
  fi
  mapfile -t files < <(ls -1t "${LAB_HOME_DIR}/results"/*.log 2>/dev/null | head -n 3)
fi

if (( ${#files[@]} == 0 )); then
  echo "No benchmark logs found." >&2
  exit 1
fi

for file in "${files[@]}"; do
  summary "$file"
done
