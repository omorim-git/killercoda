#!/usr/bin/env bash
set -euo pipefail

results_dir="${HOME}/kc-patroni-lab/results"

summary() {
  local file="$1"
  local tps
  local latency

  tps="$(grep -E '^tps =' "$file" | tail -n 1 | awk '{print $3}' || true)"
  latency="$(grep -E '^latency average =' "$file" | tail -n 1 | awk '{print $4, $5}' || true)"

  printf '%s\n' "file: $file"
  printf '%s\n' "  latency average: ${latency:-n/a}"
  printf '%s\n' "  tps: ${tps:-n/a}"
}

mapfile -t files < <(printf '%s\n' "$@" | sed '/^$/d')
if (( ${#files[@]} == 0 )); then
  if [[ ! -d "$results_dir" ]]; then
    echo "No results directory: $results_dir" >&2
    exit 1
  fi
  mapfile -t files < <(ls -1t "$results_dir"/*.log 2>/dev/null | head -n 2)
fi

if (( ${#files[@]} == 0 )); then
  echo "No benchmark logs found." >&2
  exit 1
fi

for file in "${files[@]}"; do
  summary "$file"
done
