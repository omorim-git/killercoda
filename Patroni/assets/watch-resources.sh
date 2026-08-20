#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

label="${1:-resource-watch}"
duration_seconds="${2:-30}"
interval_seconds="${3:-5}"

results_dir="${LAB_HOME_DIR}/results"
mkdir -p "$results_dir"

timestamp="$(date +%Y%m%d-%H%M%S)"
outfile="${results_dir}/${timestamp}-${label}.resources.log"
snapshot_count=$(( (duration_seconds + interval_seconds - 1) / interval_seconds ))

echo "[resources] label=${label} duration=${duration_seconds}s interval=${interval_seconds}s output=${outfile}"
"${BASH_SOURCE%/*}/resource-status.sh" "$snapshot_count" "$interval_seconds" | tee "$outfile"
echo "Saved: $outfile"
