#!/bin/bash
set -euo pipefail

LAB_ASSET_DIR="/root/kc-patroni-lab"
UPDATE_SCRIPT="${LAB_ASSET_DIR}/apply-update.sh"
LOG_FILE="/tmp/kc-patroni-lab-update.log"
FAIL_FILE="/tmp/kc-patroni-lab-update.failed"
DONE_FILE="/tmp/kc-patroni-lab-update.finished"

rm -f "$FAIL_FILE" "$DONE_FILE"

while true; do
  if [ -f /tmp/background-finished ]; then
    break
  fi

  if [ -f /tmp/kc-patroni-lab-bootstrap.failed ]; then
    echo "bootstrap failed before trouble injection" >"$LOG_FILE"
    touch "$FAIL_FILE"
    exit 1
  fi

  sleep 1
done

if bash "$UPDATE_SCRIPT" >"$LOG_FILE" 2>&1; then
  touch "$DONE_FILE"
else
  status=$?
  printf '[update] apply-update.sh failed with status %s; see %s\n' "$status" "$LOG_FILE" >>"$LOG_FILE"
  touch "$FAIL_FILE"
  # Killercoda treats a non-zero background-step exit as a platform error popup.
  # Keep the failure marker and log as the exercise's diagnostic signal instead.
  exit 0
fi
sleep 1
exit 0
