#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [ ! -f /tmp/background-finished ]; do
  sleep 1
done

bash "$SCRIPT_DIR/scripts/apply-update.sh" >/tmp/kc-patroni-lab-update.log 2>&1
