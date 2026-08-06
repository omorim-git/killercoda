#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

export DEBIAN_FRONTEND=noninteractive

log() {
  echo "[install] $*"
}

dump_failure_context() {
  echo "== kubectl get nodes -o wide ==" >&2
  kubectl get nodes -o wide >&2 || true

  echo "== kubectl get pods -A -o wide ==" >&2
  kubectl get pods -A -o wide >&2 || true

  if kubectl get namespace "$K8S_NAMESPACE" >/dev/null 2>&1; then
    echo "== tat-api describe ==" >&2
    kctl describe deployment "$API_DEPLOYMENT" >&2 || true
    kctl describe pod -l app="$API_APP_LABEL" >&2 || true

    echo "== tat-api logs ==" >&2
    kctl logs deploy/"$API_DEPLOYMENT" >&2 || true
  fi

  echo "== nftables table ==" >&2
  run_root nft list table inet "$NFT_TABLE" >&2 2>/dev/null || true
}

trap dump_failure_context ERR

wait_for_nodes_ready() {
  log "Waiting for Kubernetes nodes"
  kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null

  if [[ -z "$(worker_node)" ]]; then
    echo "worker node not found" >&2
    exit 1
  fi
}

cleanup_previous() {
  log "Cleaning previous lab state"

  kubectl delete namespace "$K8S_NAMESPACE" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  run_root nft delete table inet "$NFT_TABLE" >/dev/null 2>&1 || true

  rm -rf "$LAB_RUNTIME_DIR"
  mkdir -p "$LAB_RUNTIME_DIR" "${LAB_HOME_DIR}/results"
  rm -f /tmp/kc-patroni-lab-update.log /tmp/kc-patroni-lab-update.failed /tmp/kc-patroni-lab-update.finished
}

apply_api_manifest() {
  local cp_node

  cp_node="$(controlplane_node)"

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${K8S_NAMESPACE}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tat-api-code
  namespace: ${K8S_NAMESPACE}
data:
  server.py: |
    import json
    import os
    import socket
    import time
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    PORT = int(os.environ.get("PORT", "8080"))
    SLEEP_MS = float(os.environ.get("SLEEP_MS", "2.5"))

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def _write_json(self, status_code, payload):
            body = json.dumps(payload).encode()
            self.send_response(status_code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, fmt, *args):
            return

        def do_GET(self):
            started = time.perf_counter()
            if self.path == "/healthz":
                self._write_json(200, {"status": "ok", "host": socket.gethostname()})
                return

            if self.path.startswith("/txn"):
                if SLEEP_MS > 0:
                    time.sleep(SLEEP_MS / 1000.0)

                elapsed_ms = round((time.perf_counter() - started) * 1000, 3)
                self._write_json(
                    200,
                    {
                        "status": "ok",
                        "host": socket.gethostname(),
                        "service_time_ms": elapsed_ms,
                    },
                )
                return

            self._write_json(404, {"status": "not-found"})

    if __name__ == "__main__":
        server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
        server.serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${API_DEPLOYMENT}
  namespace: ${K8S_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${API_APP_LABEL}
  template:
    metadata:
      labels:
        app: ${API_APP_LABEL}
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${cp_node}
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: api
          image: python:3.12-slim
          imagePullPolicy: IfNotPresent
          command: ["python", "/app/server.py"]
          env:
            - name: PORT
              value: "${API_PORT}"
            - name: SLEEP_MS
              value: "2.5"
          ports:
            - containerPort: ${API_PORT}
          readinessProbe:
            httpGet:
              path: ${API_HEALTH_PATH}
              port: ${API_PORT}
            initialDelaySeconds: 2
            periodSeconds: 2
          livenessProbe:
            httpGet:
              path: ${API_HEALTH_PATH}
              port: ${API_PORT}
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            requests:
              cpu: 100m
              memory: 96Mi
            limits:
              cpu: 500m
              memory: 256Mi
          volumeMounts:
            - name: code
              mountPath: /app
      volumes:
        - name: code
          configMap:
            name: tat-api-code
EOF
}

log "Installing host dependencies"
apt-get update
apt-get install -y --no-install-recommends curl jq nftables ca-certificates

wait_for_nodes_ready
cleanup_previous

log "Recording cluster topology"
printf '%s\n' "$(controlplane_node)" >"${LAB_RUNTIME_DIR}/controlplane_node"
printf '%s\n' "$(worker_node)" >"${LAB_RUNTIME_DIR}/worker_node"
printf '%s\n' "$(controlplane_ip)" >"${LAB_RUNTIME_DIR}/controlplane_ip"
printf '%s\n' "$(worker_ip)" >"${LAB_RUNTIME_DIR}/worker_ip"

log "Deploying API pod on controlplane"
apply_api_manifest
kubectl rollout status -n "$K8S_NAMESPACE" deployment/"$API_DEPLOYMENT" --timeout=180s >/dev/null

for _ in $(seq 1 30); do
  if api_healthy; then
    break
  fi
  sleep 2
done

api_healthy
run_root nft delete table inet "$NFT_TABLE" >/dev/null 2>&1 || true
rm -f "$UPDATE_MARKER"

log "Lab is ready"
