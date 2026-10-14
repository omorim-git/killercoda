#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
export DEBIAN_FRONTEND=noninteractive

log() { echo "[install] $*"; }

dump_failure_context() {
  echo "== nodes / pods ==" >&2
  kubectl get nodes -o wide >&2 || true
  kubectl get pods -n "$K8S_NAMESPACE" -o wide >&2 || true
  kubectl describe pods -n "$K8S_NAMESPACE" >&2 || true
  kubectl get endpoints -n "$K8S_NAMESPACE" >&2 || true
  kubectl logs -n "$K8S_NAMESPACE" -l "cluster-name=${DB_CLUSTER}" --all-containers --tail=300 >&2 || true
  kubectl logs -n "$K8S_NAMESPACE" deploy/kc-etcd --all-containers --tail=100 >&2 || true
  if kubectl get deployment "$API_DEPLOYMENT" -n "$K8S_NAMESPACE" >/dev/null 2>&1; then
    kubectl logs -n "$K8S_NAMESPACE" deploy/"$API_DEPLOYMENT" --tail=100 >&2 || true
  fi
}
trap dump_failure_context ERR

wait_for_nodes_ready() {
  log "Waiting for the two Kubernetes nodes"
  kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null
  [[ -n "$(worker_node)" ]] || { echo "worker node not found" >&2; exit 1; }
}

wait_for_deployment() {
  local name="$1" expected="$2" timeout="$3" start now ready pods selector
  case "$name" in
    kc-etcd) selector="app=kc-etcd" ;;
    db-primary) selector="member-name=primary" ;;
    db-standby) selector="member-name=standby" ;;
    *) selector="app=${API_APP_LABEL}" ;;
  esac
  start="$(date +%s)"
  while true; do
    ready="$(kubectl get deployment "$name" -n "$K8S_NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
    if [[ "$ready" == "$expected" ]]; then
      log "${name} is ready (${ready}/${expected})"
      return 0
    fi
    now="$(date +%s)"
    if (( now - start >= timeout )); then
      echo "Timed out waiting for ${name} after ${timeout}s (ready=${ready:-0}/${expected})" >&2
      return 1
    fi
    pods="$(kubectl get pods -n "$K8S_NAMESPACE" -l "$selector" \
      -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,PHASE:.status.phase,REASON:.status.containerStatuses[0].state.waiting.reason' --no-headers 2>/dev/null | tr '\n' ';' || true)"
    log "Waiting for ${name}: $((now - start))s elapsed; ready=${ready:-0}/${expected}; ${pods:-pod not created yet}"
    sleep 10
  done
}

cleanup_previous() {
  log "Cleaning previous lab state"
  kubectl delete namespace "$K8S_NAMESPACE" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  nft_delete_from_all_nodes
  rm -rf "$LAB_RUNTIME_DIR"
  mkdir -p "$LAB_RUNTIME_DIR" "${LAB_HOME_DIR}/results"
  rm -f /tmp/kc-patroni-lab-update.log /tmp/kc-patroni-lab-update.failed /tmp/kc-patroni-lab-update.finished
}

apply_database_manifests() {
  local cp_node worker cp_ip worker_ip
  cp_node="$(controlplane_node)"
  worker="$(worker_node)"
  cp_ip="$(node_internal_ip "$cp_node")"
  worker_ip="$(node_internal_ip "$worker")"

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${K8S_NAMESPACE}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kc-etcd
  namespace: ${K8S_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels: {app: kc-etcd}
  template:
    metadata:
      labels: {app: kc-etcd, cluster-name: ${DB_CLUSTER}}
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${worker}
      tolerations:
        - {key: node-role.kubernetes.io/control-plane, operator: Exists, effect: NoSchedule}
        - {key: node-role.kubernetes.io/master, operator: Exists, effect: NoSchedule}
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      automountServiceAccountToken: false
      containers:
        - name: etcd
          image: quay.io/coreos/etcd:v3.5.21
          imagePullPolicy: IfNotPresent
          command: ["/usr/local/bin/etcd"]
          args:
            - --name=kc-etcd
            - --data-dir=/var/lib/etcd
            - --listen-client-urls=http://0.0.0.0:2379
            - --advertise-client-urls=http://${worker_ip}:2379
            - --listen-peer-urls=http://0.0.0.0:2380
            - --initial-advertise-peer-urls=http://${worker_ip}:2380
            - --initial-cluster=kc-etcd=http://${worker_ip}:2380
            - --initial-cluster-state=new
          ports:
            - {name: client, containerPort: 2379}
          readinessProbe:
            tcpSocket: {port: 2379}
            periodSeconds: 3
          livenessProbe:
            tcpSocket: {port: 2379}
            periodSeconds: 10
          resources:
            requests: {cpu: 100m, memory: 128Mi}
            limits: {cpu: 500m, memory: 512Mi}
          volumeMounts:
            - {name: data, mountPath: /var/lib/etcd}
      volumes:
        - name: data
          emptyDir: {}
---
# Route API traffic to the fixed Primary Pod in this two-node exercise.
apiVersion: v1
kind: Service
metadata:
  name: ${DB_CLUSTER}
  namespace: ${K8S_NAMESPACE}
  labels:
    application: ${DB_APP_LABEL}
    cluster-name: ${DB_CLUSTER}
spec:
  selector:
    member-name: primary
  ports:
    - name: postgresql
      port: ${DB_PORT}
      targetPort: ${DB_PORT}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${API_DEPLOYMENT}-code
  namespace: ${K8S_NAMESPACE}
data:
  server.py: |
    import json
    import os
    import socket
    import time
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    from psycopg2.pool import ThreadedConnectionPool

    PORT = int(os.environ.get("PORT", "8080"))
    pool = ThreadedConnectionPool(
        1, 64,
        host=os.environ["DB_HOST"], port=int(os.environ.get("DB_PORT", "5432")),
        dbname=os.environ.get("DB_NAME", "postgres"),
        user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"],
        connect_timeout=3, application_name="tat-api")

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"
        def _reply(self, status, payload):
            body = json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(body)
        def log_message(self, fmt, *args):
            return
        def do_GET(self):
            started = time.perf_counter()
            if self.path not in ("/healthz", "/txn"):
                self._reply(404, {"status": "not-found"})
                return
            conn = None
            try:
                conn = pool.getconn()
                with conn.cursor() as cur:
                    cur.execute("SELECT 1") if self.path == "/healthz" else cur.execute(
                        "INSERT INTO api_requests DEFAULT VALUES RETURNING id")
                    row = cur.fetchone()
                if self.path == "/txn":
                    conn.commit()
                else:
                    conn.rollback()
                elapsed = round((time.perf_counter() - started) * 1000, 3)
                self._reply(200, {"status": "ok", "host": socket.gethostname(),
                                  "id": row[0] if self.path == "/txn" else None,
                                  "service_time_ms": elapsed})
            except Exception as exc:
                if conn is not None:
                    conn.rollback()
                self._reply(503, {"status": "database-error", "error": str(exc)[:160]})
            finally:
                if conn is not None:
                    pool.putconn(conn)

    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-primary
  namespace: ${K8S_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      cluster-name: ${DB_CLUSTER}
      member-name: primary
  template:
    metadata:
      labels:
        application: ${DB_APP_LABEL}
        cluster-name: ${DB_CLUSTER}
        member-name: primary
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
        - name: postgres
          image: ${DB_IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - {name: SCOPE, value: "${DB_CLUSTER}"}
            - {name: PATRONI_SCOPE, value: "${DB_CLUSTER}"}
            - {name: ETCD3_HOSTS, value: "${worker_ip}:2379"}
            - {name: PATRONI_NAME, value: primary}
            - {name: POD_IP, valueFrom: {fieldRef: {fieldPath: status.podIP}}}
            - {name: PATRONI_POSTGRESQL_LISTEN, value: "0.0.0.0:5432"}
            - {name: PATRONI_POSTGRESQL_CONNECT_ADDRESS, value: "${cp_ip}:5432"}
            - {name: PATRONI_RESTAPI_LISTEN, value: "0.0.0.0:8008"}
            - {name: PATRONI_RESTAPI_CONNECT_ADDRESS, value: "${cp_ip}:8008"}
            - {name: PATRONI_REPLICATION_USERNAME, value: standby}
            - {name: PATRONI_REPLICATION_PASSWORD, value: "${DB_REPLICATION_PASSWORD}"}
            - {name: PATRONI_SUPERUSER_USERNAME, value: postgres}
            - {name: PATRONI_SUPERUSER_PASSWORD, value: "${DB_SUPERUSER_PASSWORD}"}
            - {name: PGPASSWORD_SUPERUSER, value: "${DB_SUPERUSER_PASSWORD}"}
            - {name: PGPASSWORD_STANDBY, value: "${DB_REPLICATION_PASSWORD}"}
            - name: SPILO_CONFIGURATION
              value: >-
                {"bootstrap":{"dcs":{"synchronous_mode":true,"synchronous_mode_strict":true,"synchronous_node_count":1,"postgresql":{"parameters":{"synchronous_commit":"on"}}},"initdb":[{"auth-host":"md5"},{"auth-local":"trust"}],"users":{"${DB_APP_USER}":{"password":"${DB_APP_PASSWORD}","options":["createdb"]}}},"postgresql":{"parameters":{"synchronous_commit":"on"},"pg_hba":["host all all 0.0.0.0/0 md5","host replication standby 0.0.0.0/0 md5"]}}
          ports:
            - {name: postgresql, containerPort: 5432, hostPort: 5432}
            - {name: patroni, containerPort: 8008, hostPort: 8008}
          volumeMounts:
            - {name: data, mountPath: /home/postgres/pgdata}
          readinessProbe:
            httpGet: {path: /health, port: 8008}
            periodSeconds: 5
            failureThreshold: 30
          resources:
            requests: {cpu: 250m, memory: 512Mi}
            limits: {cpu: "1500m", memory: 1536Mi}
      volumes:
        - name: data
          emptyDir: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-standby
  namespace: ${K8S_NAMESPACE}
spec:
  replicas: 0
  selector:
    matchLabels:
      cluster-name: ${DB_CLUSTER}
      member-name: standby
  template:
    metadata:
      labels:
        application: ${DB_APP_LABEL}
        cluster-name: ${DB_CLUSTER}
        member-name: standby
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${worker}
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: postgres
          image: ${DB_IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - {name: SCOPE, value: "${DB_CLUSTER}"}
            - {name: PATRONI_SCOPE, value: "${DB_CLUSTER}"}
            - {name: ETCD3_HOSTS, value: "${worker_ip}:2379"}
            - {name: PATRONI_NAME, value: standby}
            - {name: POD_IP, valueFrom: {fieldRef: {fieldPath: status.podIP}}}
            - {name: PATRONI_POSTGRESQL_LISTEN, value: "0.0.0.0:5432"}
            - {name: PATRONI_POSTGRESQL_CONNECT_ADDRESS, value: "${worker_ip}:5432"}
            - {name: PATRONI_RESTAPI_LISTEN, value: "0.0.0.0:8008"}
            - {name: PATRONI_RESTAPI_CONNECT_ADDRESS, value: "${worker_ip}:8008"}
            - {name: PATRONI_REPLICATION_USERNAME, value: standby}
            - {name: PATRONI_REPLICATION_PASSWORD, value: "${DB_REPLICATION_PASSWORD}"}
            - {name: PATRONI_SUPERUSER_USERNAME, value: postgres}
            - {name: PATRONI_SUPERUSER_PASSWORD, value: "${DB_SUPERUSER_PASSWORD}"}
            - {name: PGPASSWORD_SUPERUSER, value: "${DB_SUPERUSER_PASSWORD}"}
            - {name: PGPASSWORD_STANDBY, value: "${DB_REPLICATION_PASSWORD}"}
            - name: SPILO_CONFIGURATION
              value: >-
                {"bootstrap":{"dcs":{"synchronous_mode":true,"synchronous_mode_strict":true,"synchronous_node_count":1,"postgresql":{"parameters":{"synchronous_commit":"on"}}},"initdb":[{"auth-host":"md5"},{"auth-local":"trust"}],"users":{"${DB_APP_USER}":{"password":"${DB_APP_PASSWORD}","options":["createdb"]}}},"postgresql":{"parameters":{"synchronous_commit":"on"},"pg_hba":["host all all 0.0.0.0/0 md5","host replication standby 0.0.0.0/0 md5"]}}
          ports:
            - {name: postgresql, containerPort: 5432, hostPort: 5432}
            - {name: patroni, containerPort: 8008, hostPort: 8008}
          volumeMounts:
            - {name: data, mountPath: /home/postgres/pgdata}
          readinessProbe:
            httpGet: {path: /health, port: 8008}
            periodSeconds: 5
            failureThreshold: 30
          resources:
            requests: {cpu: 250m, memory: 512Mi}
            limits: {cpu: "1500m", memory: 1536Mi}
      volumes:
        - name: data
          emptyDir: {}
EOF
}

apply_api_deployment() {
  local cp_node
  cp_node="$(controlplane_node)"
  kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${API_DEPLOYMENT}
  namespace: ${K8S_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels: {app: ${API_APP_LABEL}}
  template:
    metadata:
      labels: {app: ${API_APP_LABEL}}
    spec:
      nodeSelector: {kubernetes.io/hostname: ${cp_node}}
      tolerations:
        - {key: node-role.kubernetes.io/control-plane, operator: Exists, effect: NoSchedule}
        - {key: node-role.kubernetes.io/master, operator: Exists, effect: NoSchedule}
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: api
          image: ${DB_IMAGE}
          imagePullPolicy: IfNotPresent
          command: ["python3", "-u", "/app/server.py"]
          env:
            - {name: PORT, value: "${API_PORT}"}
            - {name: DB_HOST, value: "${DB_SERVICE}.${K8S_NAMESPACE}.svc.cluster.local"}
            - {name: DB_PORT, value: "${DB_PORT}"}
            - {name: DB_NAME, value: "${DB_NAME}"}
            - {name: DB_USER, value: "${DB_APP_USER}"}
            - {name: DB_PASSWORD, value: "${DB_APP_PASSWORD}"}
          ports: [{containerPort: ${API_PORT}}]
          readinessProbe:
            httpGet: {path: ${API_HEALTH_PATH}, port: ${API_PORT}}
            periodSeconds: 3
          resources:
            requests: {cpu: 100m, memory: 128Mi}
            limits: {cpu: 750m, memory: 512Mi}
          volumeMounts: [{name: code, mountPath: /app}]
      volumes:
        - name: code
          configMap: {name: ${API_DEPLOYMENT}-code}
EOF
}

log "Installing host dependencies"
apt-get update
apt-get install -y --no-install-recommends curl jq nftables ca-certificates procps sysstat python3 openssh-client

wait_for_nodes_ready
cleanup_previous
log "Recording node placement"
printf '%s\n' "$(controlplane_node)" >"${LAB_RUNTIME_DIR}/controlplane_node"
printf '%s\n' "$(worker_node)" >"${LAB_RUNTIME_DIR}/worker_node"
printf '%s\n' "$(controlplane_ip)" >"${LAB_RUNTIME_DIR}/controlplane_ip"
printf '%s\n' "$(worker_ip)" >"${LAB_RUNTIME_DIR}/worker_ip"

log "Creating etcd DCS and PostgreSQL pods"
apply_database_manifests
wait_for_deployment kc-etcd 1 180
wait_for_deployment db-primary 1 300
kubectl scale -n "$K8S_NAMESPACE" deployment/db-standby --replicas=1 >/dev/null
wait_for_deployment db-standby 1 300

log "Waiting for synchronous replication"
ready=0
for _ in $(seq 1 120); do
  primary="$(db_primary_pod_name 2>/dev/null || true)"
  standby="$(db_standby_pod_name 2>/dev/null || true)"
  if [[ -n "$primary" && -n "$standby" ]] && kctl exec "$primary" -- psql -U postgres -d postgres -Atqc "SELECT count(*) FROM pg_stat_replication WHERE state='streaming' AND sync_state='sync'" 2>/dev/null | grep -qx 1; then
    ready=1
    break
  fi
  sleep 3
done
if (( ready == 0 )); then
  echo "Patroni synchronous standby did not become ready" >&2
  exit 1
fi

log "Creating the API transaction table"
primary="$(db_primary_pod_name)"
kctl exec "$primary" -- psql -U postgres -d "$DB_NAME" -v ON_ERROR_STOP=1 -c \
  'CREATE TABLE IF NOT EXISTS api_requests (id bigserial PRIMARY KEY, created_at timestamptz NOT NULL DEFAULT now())' >/dev/null
kctl exec "$primary" -- psql -U postgres -d "$DB_NAME" -v ON_ERROR_STOP=1 -c \
  "GRANT INSERT ON TABLE api_requests TO ${DB_APP_USER}; GRANT USAGE, SELECT ON SEQUENCE api_requests_id_seq TO ${DB_APP_USER};" >/dev/null

log "Deploying API on the primary node"
apply_api_deployment
wait_for_deployment "$API_DEPLOYMENT" 1 180
for _ in $(seq 1 30); do
  if api_healthy; then break; fi
  sleep 2
done
api_healthy
nft_delete_from_all_nodes
rm -f "$UPDATE_MARKER"
log "Lab is ready"
