#!/bin/bash
set -euo pipefail

READY_FILE="/tmp/step3-trouble-started"

echo "トラブル発生2 の状態へ切り替え中です..."
while [ ! -f "${READY_FILE}" ]; do
  sleep 1
done
echo "トラブル発生2 の状態に切り替えました。調査を開始してください。"
