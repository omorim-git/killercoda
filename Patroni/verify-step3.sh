#!/bin/bash
set -euo pipefail

LAB_ASSET_DIR="/root/kc-patroni-lab"
source "$LAB_ASSET_DIR/lib.sh"

issues=()
results_dir="${LAB_HOME_DIR}/results"
worker_log="$(find "$results_dir" -maxdepth 1 -type f -name 'worker-after-update-*.vmstat.log' 2>/dev/null | sort | tail -n 1)"
bundle="$(find "$results_dir" -maxdepth 1 -type f -name '*-analysis-bundle.txt' 2>/dev/null | sort | tail -n 1)"

if [[ -z "$(find_latest_result "after-update-worker")" ]]; then
  issues+=("劣化時レートの測定ログがありません。Step3のworker CPU採取とbenchmarkコマンドを実行してください。")
fi

if [[ -z "$worker_log" ]]; then
  issues+=("worker側vmstatログがありません。Step3の採取コマンドを実行してください。")
elif ! grep -Eq '(^|[[:space:]])us[[:space:]]+sy[[:space:]]+id[[:space:]]+wa[[:space:]]+st([[:space:]]|$)' "$worker_log"; then
  issues+=("worker側vmstatログにCPU列がありません。SSH接続とworker上のvmstat実行結果を確認してください。")
fi

if [[ -z "$bundle" ]]; then
  issues+=("調査用bundleがありません。analysis-bundle.shを実行してください。")
elif [[ -n "$worker_log" ]] && ! grep -Fq "${worker_log##*/}" "$bundle"; then
  issues+=("bundleにworker CPUログが含まれていません。workerログ採取後にanalysis-bundle.shを再実行してください。")
fi

if (( ${#issues[@]} > 0 )); then
  printf '%s\n' "${issues[@]}"
  exit 1
fi

echo "追加調査用の測定ログ、worker CPU記録、analysis bundleを確認しました。原因の断定と復旧は別途の解説で行ってください。"
