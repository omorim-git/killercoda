#!/bin/bash

echo "[1/6] Create namespace"
kubectl apply -f /etc/kc_relay_web/00-namespace.yaml

echo "[2/6] Label two nodes (hotspot / normal)"
mapfile -t NODES < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
if [ "${#NODES[@]}" -lt 2 ]; then
  echo "ERROR: 2ノード以上が必要です"; exit 1
fi
HOT="${NODES[0]}"
NORM="${NODES[1]}"
kubectl label node "${HOT}" role=hotspot --overwrite
kubectl label node "${NORM}" role=normal  --overwrite
echo "  hotspot: ${HOT}"
echo "  normal : ${NORM}"

echo "[3/6] Apply manifests"
kubectl apply -f /etc/kc_relay_web/10-frontend-configmap.yaml
kubectl apply -f /etc/kc_relay_web/11-frontend.yaml
kubectl apply -f /etc/kc_relay_web/20-relay-configmap.yaml
kubectl apply -f /etc/kc_relay_web/21-relay.yaml
kubectl apply -f /etc/kc_relay_web/30-backend-configmap.yaml
kubectl apply -f /etc/kc_relay_web/31-backend.yaml
kubectl apply -f /etc/kc_relay_web/40-cpuhog.yaml

echo "[4/6] Wait for deployments (frontend, relay, backend)"
kubectl -n latency-demo rollout status deploy/frontend
kubectl -n latency-demo rollout status deploy/relay
kubectl -n latency-demo rollout status deploy/backend

echo "[5/6] Show access info"
NODE_IP=$(kubectl get node "${NORM}" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
FR_PORT=30080
RELAY_PORT=30081
cat <<EOF

アクセス方法:
- フロント:  http://${NODE_IP}:${FR_PORT}/
  (ページの JS はリレーを http://<同じホスト名>:${RELAY_PORT} へ呼び出します)

EOF

echo "[6/6] Schedule CPU hog start (in 120s)"
(
  sleep 120
  echo "[*] Starting CPU hog (replicas=1) on hotspot node…"
  kubectl -n latency-demo scale deploy/cpu-hog --replicas=1
) &

echo "セットアップ完了。ブラウザでフロントにアクセスしてリクエストを送ってください。"

