#!/bin/bash
set -euo pipefail

READY_FILE="/tmp/step3-trouble-started"

echo "Step3 のトラブル状態へ切り替え中です..."
while [ ! -f "${READY_FILE}" ]; do
  sleep 1
done
echo "Step3 のトラブル状態に切り替えました。調査を開始してください。"
