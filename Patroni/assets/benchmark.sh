#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

label="${1:-manual}"
duration="${2:-20}"
clients="${3:-8}"
jobs="${4:-2}"

results_dir="${LAB_HOME_DIR}/results"
mkdir -p "$results_dir"

timestamp="$(date +%Y%m%d-%H%M%S)"
outfile="${results_dir}/${timestamp}-${label}.log"

{
  echo "[benchmark] label=${label} duration=${duration}s clients=${clients} jobs=${jobs}"
  ns_exec "$CLIENT_NS" env PGPASSWORD="$APP_PASSWORD" \
    pgbench -h "$PRIMARY_IP" -p 5432 -U "$APP_USER" -N -T "$duration" -P 5 -c "$clients" -j "$jobs" "$BENCH_DB"
} | tee "$outfile"

echo "Saved: $outfile"
