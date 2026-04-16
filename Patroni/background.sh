#!/bin/bash
set -euo pipefail

LAB_ASSET_DIR="${HOME}/kc-patroni-lab"
INSTALL_SCRIPT="${LAB_ASSET_DIR}/install-lab.sh"
LOG_FILE="/tmp/kc-patroni-lab-bootstrap.log"
FAIL_FILE="/tmp/kc-patroni-lab-bootstrap.failed"
UPDATE_FAIL_FILE="/tmp/kc-patroni-lab-update.failed"
UPDATE_DONE_FILE="/tmp/kc-patroni-lab-update.finished"

rm -f "$FAIL_FILE" /tmp/background-finished "$UPDATE_FAIL_FILE" "$UPDATE_DONE_FILE"

for _ in $(seq 1 30); do
  if [ -f "$INSTALL_SCRIPT" ]; then
    break
  fi
  sleep 1
done

if ! bash "$INSTALL_SCRIPT" >"$LOG_FILE" 2>&1; then
  touch "$FAIL_FILE"
  exit 1
fi

touch /tmp/background-finished
