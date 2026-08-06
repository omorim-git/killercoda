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

rule_ip_for_index() {
  local index="$1"
  local second
  local third
  local fourth

  # Use 198.18.0.0/15 (198.18.0.0 - 198.19.255.255) so up to 131072
  # distinct IPv4 addresses can be generated for non-matching blacklist rules.
  second=$(( 18 + ((index / 65536) % 2) ))
  third=$(( (index / 256) % 256 ))
  fourth=$(( index % 256 ))

  printf '198.%d.%d.%d' "$second" "$third" "$fourth"
}

if [[ -f "$UPDATE_MARKER" ]]; then
  log "Update state has already been applied"
  exit 0
fi

if (( NFT_RULE_COUNT < 1 )); then
  echo "NFT_RULE_COUNT must be >= 1" >&2
  exit 1
fi

if (( NFT_RULE_COUNT > 131072 )); then
  echo "NFT_RULE_COUNT=${NFT_RULE_COUNT} exceeds supported maximum 131072" >&2
  exit 1
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
    printf '    ip saddr %s drop\n' "$(rule_ip_for_index "$i")"
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
