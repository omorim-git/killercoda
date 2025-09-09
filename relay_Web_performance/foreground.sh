#!/bin/bash

echo "[1/5] Namespace"
kubectl apply -f /etc/kc_relay_web/00-namespace.yaml

echo "[2/5] Manifests"
kubectl apply -f /etc/kc_relay_web/10-frontend-configmap.yaml
kubectl apply -f /etc/kc_relay_web/11-frontend.yaml
kubectl apply -f /etc/kc_relay_web/20-relay-configmap.yaml
kubectl apply -f /etc/kc_relay_web/21-relay.yaml
kubectl apply -f /etc/kc_relay_web/30-backend-configmap.yaml
kubectl apply -f /etc/kc_relay_web/31-backend.yaml

echo "[3/5] Rollout"
kubectl -n latency-demo rollout status deploy/frontend
kubectl -n latency-demo rollout status deploy/relay
kubectl -n latency-demo rollout status deploy/backend

echo "[4/5] Access URL"
NODE_IP=$(kubectl get node node01 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "Open:  http://${NODE_IP}:30081/   (relay経由でフロント表示)"

echo "[5/5] Notes"
echo "- 通常リクエストの履歴で基準性能を確認してください。"
