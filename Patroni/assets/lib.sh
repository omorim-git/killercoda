#!/usr/bin/env bash
set -euo pipefail

LAB_NAME="kc-patroni-lab"
LAB_RUNTIME_DIR="/var/lib/${LAB_NAME}"
LAB_HOME_DIR="${HOME}/kc-patroni-lab"
ARTIFACT_DIR="${LAB_RUNTIME_DIR}/graphs"
ARTIFACT_PORT="8090"

K8S_NAMESPACE="tat-lab"
API_DEPLOYMENT="tat-api"
API_APP_LABEL="tat-api"
API_PORT="18080"
API_HEALTH_PATH="/healthz"
API_TXN_PATH="/txn"
K6_JOB_PREFIX="tat-k6"
DB_CLUSTER="kc-sync-lab"
DB_APP_LABEL="spilo"
DB_ROLE_LABEL="spilo-role"
DB_PRIMARY_LABEL="master"
DB_STANDBY_LABEL="replica"
DB_SERVICE="$DB_CLUSTER"
DB_PORT="5432"
DB_NAME="postgres"
DB_APP_USER="tatapp"
DB_APP_PASSWORD="tatapp-lab-password"
DB_SUPERUSER_PASSWORD="postgres-lab-password"
DB_REPLICATION_PASSWORD="replication-lab-password"
DB_IMAGE="ghcr.io/zalando/spilo-17:4.0-p2"

NFT_TABLE="kc_tat_lab"
NFT_FORWARD_CHAIN="forward"
NFT_INTERFACE_CHAIN="interface_gate"
NFT_GUARD_CHAIN="replication_guard"
NFT_SERVICE_CHAIN="service_guard"
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
  kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' |
    awk -v cp="$cp" '$0 != cp && !found {print; found=1}'
}

node_internal_ip() {
  local node="$1"

  kubectl get node "$node" -o jsonpath='{range .status.addresses[*]}{.type}{"="}{.address}{"\n"}{end}' |
    awk -F= '$1=="InternalIP" && !found {print $2; found=1}'
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

db_primary_pod_name() {
  kctl get pod -l "cluster-name=${DB_CLUSTER},member-name=primary" -o jsonpath='{.items[0].metadata.name}'
}

db_standby_pod_name() {
  kctl get pod -l "cluster-name=${DB_CLUSTER},member-name=standby" -o jsonpath='{.items[0].metadata.name}'
}

db_pod_node() {
  local pod="$1"
  kctl get pod "$pod" -o jsonpath='{.spec.nodeName}'
}

db_standby_node() {
  local pod
  pod="$(db_standby_pod_name 2>/dev/null || true)"
  [[ -n "$pod" ]] || return 1
  db_pod_node "$pod"
}

api_healthy() {
  curl -fsS --max-time 3 "$(api_health_url)" >/dev/null
}

ensure_artifact_server() {
  local script_dir
  local attempt

  mkdir -p "$ARTIFACT_DIR"
  if curl -fsS --max-time 1 "http://127.0.0.1:${ARTIFACT_PORT}/" >/dev/null 2>&1; then
    return 0
  fi

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  nohup python3 "${script_dir}/artifact-server.py" --directory "$ARTIFACT_DIR" --port "$ARTIFACT_PORT" \
    >/tmp/kc-patroni-artifact-http.log 2>&1 </dev/null &
  for attempt in $(seq 1 10); do
    if curl -fsS --max-time 1 "http://127.0.0.1:${ARTIFACT_PORT}/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "artifact HTTP server did not start; see /tmp/kc-patroni-artifact-http.log" >&2
  return 1
}

nft_table_exists() {
  local node
  node="$(db_standby_node 2>/dev/null || true)"
  [[ -n "$node" ]] || return 1
  ssh -o BatchMode=yes -o ConnectTimeout=3 "$node" sudo nft list table inet "$NFT_TABLE" >/dev/null 2>&1
}

nft_rule_count() {
  local node
  node="$(db_standby_node 2>/dev/null || true)"
  [[ -n "$node" ]] || { echo 0; return 0; }
  if ! nft_table_exists; then
    echo 0
    return 0
  fi

  ssh -o BatchMode=yes -o ConnectTimeout=3 "$node" sudo nft list chain inet "$NFT_TABLE" "$NFT_GUARD_CHAIN" 2>/dev/null | awk '/ip saddr .* jump / {c++} END {print c+0}'
}

nft_delete_from_node() {
  local node="$1"
  ssh -o BatchMode=yes -o ConnectTimeout=3 "$node" sudo nft delete table inet "$NFT_TABLE" >/dev/null 2>&1 || true
}

nft_delete_from_all_nodes() {
  local node
  while IFS= read -r node; do
    [[ -n "$node" ]] || continue
    nft_delete_from_node "$node"
  done < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
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

  awk -v metric="$metric" -v key="$key" '
    index($0, metric) && !found {
      for (i = 1; i <= NF; i++) {
        if (index($i, key "=") == 1) {
          print substr($i, length(key) + 2)
          found = 1
          break
        }
      }
    }' "$file"
}

extract_k6_failed_rate() {
  local file="$1"

  sed -n 's/.*http_req_failed.*: *\([^ ]*\).*/\1/p' "$file" | awk 'NR == 1 {print; found=1} END {if (!found) exit 0}'
}

extract_k6_dropped_iterations() {
  local file="$1"

  sed -n 's/.*dropped_iterations.*: *\([0-9][0-9]*\).*/\1/p' "$file" | awk 'NR == 1 {print; found=1} END {if (!found) exit 0}'
}

extract_k6_http_reqs_rate() {
  local file="$1"

  sed -n 's/.*http_reqs.*: *[0-9][0-9]* *\([^ ]*\/s\).*/\1/p' "$file" | awk 'NR == 1 {print; found=1} END {if (!found) exit 0}'
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

  ls -1t "${LAB_HOME_DIR}/results/"*-"${label}".log 2>/dev/null | awk 'NR == 1 {print; found=1} END {if (!found) exit 0}'
}
