#!/bin/bash
set -euo pipefail

LAB_ASSET_DIR="/root/kc-patroni-lab"
source "$LAB_ASSET_DIR/lib.sh"

issues=()

if nft_table_exists; then
  issues+=("nftables の劣化 table ${NFT_TABLE} が残っています。")
fi

if ! api_healthy; then
  issues+=("API が応答していません。")
fi

after_file="$(find_latest_result "after-update")"
recovered_file="$(find_latest_result "recovered")"

if [[ -z "$recovered_file" ]]; then
  issues+=("recovered の benchmark ログがありません。")
fi

if [[ -z "$after_file" ]]; then
  issues+=("after-update の benchmark ログがありません。")
fi

if [[ -n "$after_file" && -n "$recovered_file" ]]; then
  after_avg="$(extract_k6_stat "$after_file" 'http_req_duration' 'avg')"
  recovered_avg="$(extract_k6_stat "$recovered_file" 'http_req_duration' 'avg')"
  after_ms="$(duration_to_ms "${after_avg:-}")"
  recovered_ms="$(duration_to_ms "${recovered_avg:-}")"

  if ! awk -v a="$after_ms" -v r="$recovered_ms" 'BEGIN { exit !(a >= 0 && r >= 0 && r < a) }'; then
    issues+=("recovered の平均 TAT が after-update より改善していません。")
  fi
fi

if (( ${#issues[@]} > 0 )); then
  printf '%s\n' "${issues[@]}"
  exit 1
fi

echo "性能復旧条件を満たしています。"
