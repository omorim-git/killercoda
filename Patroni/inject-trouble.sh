#!/bin/bash
set -euo pipefail

LAB_ASSET_DIR="${HOME}/kc-patroni-lab"
UPDATE_SCRIPT="${LAB_ASSET_DIR}/apply-update.sh"

while [ ! -f /tmp/background-finished ]; do
  sleep 1
done

bash "$UPDATE_SCRIPT" >/tmp/kc-patroni-lab-update.log 2>&1
