#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/tmp/kc-patroni-lab-bootstrap.log"
FAIL_FILE="/tmp/kc-patroni-lab-bootstrap.failed"

rm -f "$FAIL_FILE"

if ! bash "$SCRIPT_DIR/scripts/install-lab.sh" >"$LOG_FILE" 2>&1; then
  touch "$FAIL_FILE"
  exit 1
fi

touch /tmp/background-finished
