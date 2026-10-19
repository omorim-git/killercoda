#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

RULESET_FILE="${LAB_RUNTIME_DIR}/nftables-bloat.nft"
STANDBY_NODE="$(db_standby_node)"

log() {
  echo "[update] $*"
}

rule_ip_for_index() {
  local index="$1"
  local address_number

  # Spread exact addresses across 10/8 instead of using one contiguous interval.
  address_number=$(( (index * 7919) % 16777214 + 1 ))

  printf '10.%d.%d.%d' "$((address_number / 65536))" "$(((address_number / 256) % 256))" "$((address_number % 256))"
}

if [[ -f "$UPDATE_MARKER" ]]; then
  log "Update state has already been applied"
  exit 0
fi

if (( NFT_RULE_COUNT < 1 )); then
  echo "NFT_RULE_COUNT must be >= 1" >&2
  exit 1
fi

if (( NFT_RULE_COUNT > 16777214 )); then
  echo "NFT_RULE_COUNT=${NFT_RULE_COUNT} exceeds supported maximum 16777214" >&2
  exit 1
fi

mkdir -p "$LAB_RUNTIME_DIR"

log "Generating nftables multi-chain rules (${NFT_RULE_COUNT} sparse source addresses)"
{
  echo "table inet ${NFT_TABLE} {"
  echo "  chain ${NFT_FORWARD_CHAIN} {"
  echo "    type filter hook forward priority 0; policy accept;"
  echo "    iifname != \"lo\" jump ${NFT_INTERFACE_CHAIN}"
  echo "  }"
  echo "  chain ${NFT_INTERFACE_CHAIN} {"
  echo "    jump ${NFT_GUARD_CHAIN}"
  echo "  }"
  echo "  chain ${NFT_GUARD_CHAIN} {"
  for i in $(seq 1 "$NFT_RULE_COUNT"); do
    printf '    ip saddr %s jump %s\n' "$(rule_ip_for_index "$i")" "$NFT_SERVICE_CHAIN"
  done
  echo "    accept"
  echo "  }"
  echo "  chain ${NFT_SERVICE_CHAIN} {"
  echo "    tcp dport { 22, 139, 445 } drop"
  echo "    udp dport { 137, 138 } drop"
  echo "    return"
  echo "  }"
  echo "}"
} >"$RULESET_FILE"

log "Applying nftables rules on standby node ${STANDBY_NODE} (SSH/SMB ports only for matching source IPs)"
ssh -o BatchMode=yes -o ConnectTimeout=5 "$STANDBY_NODE" sudo nft delete table inet "$NFT_TABLE" >/dev/null 2>&1 || true
ssh -o BatchMode=yes -o ConnectTimeout=5 "$STANDBY_NODE" sudo nft -f - <"$RULESET_FILE"

touch "$UPDATE_MARKER"
log "Update state has been applied"
