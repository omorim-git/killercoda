#!/bin/bash
set -euo pipefail

while true; do
  if [ -f /tmp/background-finished ]; then
    echo "準備完了です。"
    exit 0
  fi

  if [ -f /tmp/kc-patroni-lab-bootstrap.failed ]; then
    echo "初期化に失敗しました。/tmp/kc-patroni-lab-bootstrap.log を確認してください。"
    exit 1
  fi

  echo "環境準備中のためお待ちください..."
  sleep 5
done
