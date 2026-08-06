#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

RULESET_FILE="${LAB_RUNTIME_DIR}/nftables-bloat.nft"

log() {
  echo "[update] $*"
}

if [[ -f "$UPDATE_MARKER" ]]; then
  log "Update state has already been applied"
  exit 0
fi

mkdir -p "$LAB_RUNTIME_DIR"

log "Generating nftables rule explosion"
{
  echo "table inet ${NFT_TABLE} {"
  echo "  chain ${NFT_INPUT_CHAIN} {"
  echo "    type filter hook input priority 0; policy accept;"
  echo "    tcp dport ${API_PORT} jump ${NFT_GUARD_CHAIN}"
  echo "  }"
  echo "  chain ${NFT_GUARD_CHAIN} {"
  for i in $(seq 1 "$NFT_RULE_COUNT"); do
    third=$(( i / 256 ))
    fourth=$(( i % 256 ))
    printf '    ip saddr 198.18.%d.%d drop\n' "$third" "$fourth"
  done
  echo "    accept"
  echo "  }"
  echo "}"
} >"$RULESET_FILE"

log "Applying nftables rules"
run_root nft delete table inet "$NFT_TABLE" >/dev/null 2>&1 || true
run_root nft -f "$RULESET_FILE"

touch "$UPDATE_MARKER"
log "Update state has been applied"
