#!/bin/bash
set -euo pipefail

start_time="$(date +%s)"
last_report=0
echo "環境を準備しています。初回はイメージ取得を含め数分かかることがあります。"

while true; do
  if [ -f /tmp/background-finished ]; then
    elapsed="$(( $(date +%s) - start_time ))"
    echo "準備完了です（${elapsed}秒）。~/kc-patroni-lab/topology.sh で構成を確認できます。"
    exit 0
  fi

  if [ -f /tmp/kc-patroni-lab-bootstrap.failed ]; then
    echo "初期化に失敗しました。ログ末尾を表示します。全ログ: /tmp/kc-patroni-lab-bootstrap.log"
    tail -n 16 /tmp/kc-patroni-lab-bootstrap.log 2>/dev/null || true
    exit 1
  fi

  elapsed="$(( $(date +%s) - start_time ))"
  if (( elapsed - last_report >= 10 )); then
    phase=""
    if [ -r /tmp/kc-patroni-lab-bootstrap.log ]; then
      phase="$(grep '^\[install\]' /tmp/kc-patroni-lab-bootstrap.log | tail -n 1 | sed 's/^\[install\] //')"
    fi
    if [ -z "$phase" ]; then phase="Kubernetesノードと必要な資材を確認中"; fi
    printf '[%02d:%02d経過] 準備中: %s（初回は数分かかる場合があります）\n' \
      "$((elapsed / 60))" "$((elapsed % 60))" "$phase"
    last_report="$elapsed"
  fi
  sleep 2
done
