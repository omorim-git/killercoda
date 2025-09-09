#!/bin/bash

echo "[Step2] cpu-hog を起動してレイテンシ劣化を再現します"

kubectl apply -f /etc/kc_relay_web/40-cpuhog.yaml
kubectl -n latency-demo scale deploy/cpu-hog --replicas=1
kubectl -n latency-demo rollout status deploy/cpu-hog --timeout=120s || true

NODE_IP=$(kubectl get node node01 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "Open:  http://${NODE_IP}:30081/"
echo "※ この状態で通常リクエストを繰り返すと、合計往復時間の悪化を確認できます。"
