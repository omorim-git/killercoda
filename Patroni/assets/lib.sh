#!/usr/bin/env bash
set -euo pipefail

LAB_NAME="kc-patroni-lab"
LAB_RUNTIME_DIR="/var/lib/${LAB_NAME}"
LAB_HOME_DIR="${HOME}/kc-patroni-lab"

K8S_NAMESPACE="tat-lab"
API_DEPLOYMENT="tat-api"
API_APP_LABEL="tat-api"
API_PORT="8080"
API_HEALTH_PATH="/healthz"
API_TXN_PATH="/txn"
K6_JOB_PREFIX="tat-k6"

NFT_TABLE="kc_tat_lab"
NFT_INPUT_CHAIN="input"
NFT_GUARD_CHAIN="api_guard"
NFT_RULE_COUNT=100000
UPDATE_MARKER="${LAB_RUNTIME_DIR}/update-applied"

run_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

kctl() {
  kubectl -n "$K8S_NAMESPACE" "$@"
}

controlplane_node() {
  local node

  node="$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "$node" ]]; then
    printf '%s\n' "$node"
    return 0
  fi

  kubectl get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[0].metadata.name}'
}

worker_node() {
  local cp

  cp="$(controlplane_node)"
  kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -vx "$cp" | head -n 1
}

node_internal_ip() {
  local node="$1"

  kubectl get node "$node" -o jsonpath='{range .status.addresses[*]}{.type}{"="}{.address}{"\n"}{end}' | awk -F= '$1=="InternalIP" {print $2; exit}'
}

controlplane_ip() {
  node_internal_ip "$(controlplane_node)"
}

worker_ip() {
  node_internal_ip "$(worker_node)"
}

api_url() {
  printf 'http://%s:%s%s\n' "$(controlplane_ip)" "$API_PORT" "$API_TXN_PATH"
}

api_health_url() {
  printf 'http://%s:%s%s\n' "$(controlplane_ip)" "$API_PORT" "$API_HEALTH_PATH"
}

api_pod_name() {
  kctl get pod -l app="$API_APP_LABEL" -o jsonpath='{.items[0].metadata.name}'
}

api_pod_node() {
  kctl get pod -l app="$API_APP_LABEL" -o jsonpath='{.items[0].spec.nodeName}'
}

api_healthy() {
  curl -fsS --max-time 3 "$(api_health_url)" >/dev/null
}

nft_table_exists() {
  run_root nft list table inet "$NFT_TABLE" >/dev/null 2>&1
}

nft_rule_count() {
  if ! nft_table_exists; then
    echo 0
    return 0
  fi

  run_root nft list chain inet "$NFT_TABLE" "$NFT_GUARD_CHAIN" 2>/dev/null | awk '/ip saddr 198\.18\./ {c++} END {print c+0}'
}

update_state() {
  if [[ -f "$UPDATE_MARKER" ]]; then
    echo "applied"
  else
    echo "baseline"
  fi
}

extract_k6_stat() {
  local file="$1"
  local metric="$2"
  local key="$3"

  sed -n "s/.*${metric}.*${key}=\\([^ ]*\\).*/\\1/p" "$file" | head -n 1
}

extract_k6_failed_rate() {
  local file="$1"

  sed -n 's/.*http_req_failed.*: *\([^ ]*\).*/\1/p' "$file" | head -n 1
}

duration_to_ms() {
  local value="$1"

  awk -v v="$value" '
    function abs(x) { return x < 0 ? -x : x }
    BEGIN {
      if (v == "" || v == "n/a") {
        print "-1"
        exit 0
      }

      if (v ~ /ms$/) {
        sub(/ms$/, "", v)
        print v + 0
        exit 0
      }

      if (v ~ /µs$/) {
        sub(/µs$/, "", v)
        print (v + 0) / 1000
        exit 0
      }

      if (v ~ /us$/) {
        sub(/us$/, "", v)
        print (v + 0) / 1000
        exit 0
      }

      if (v ~ /s$/) {
        sub(/s$/, "", v)
        print (v + 0) * 1000
        exit 0
      }

      print v + 0
    }'
}

find_latest_result() {
  local label="$1"

  ls -1t "${LAB_HOME_DIR}/results/"*-"${label}".log 2>/dev/null | head -n 1
}

