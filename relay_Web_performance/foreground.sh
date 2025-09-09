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

echo "[4/5] metrics-server"
curl -sSL https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml \
| yq '
  # Deployment/metrics-server だけを書き換える
  (. | select(.kind=="Deployment" and .metadata.name=="metrics-server").spec.template.spec.terminationGracePeriodSeconds) |= 5
  |
  (. | select(.kind=="Deployment" and .metadata.name=="metrics-server").spec.template.spec.containers[0].args)
    |= ((. // []) + ["--kubelet-insecure-tls","--kubelet-preferred-address-types=InternalIP"])
' \
| kubectl apply -f -

echo "[5/5] 準備完了"
echo "準備が完了しました。Webページを開いて通常時の性能を確認してください。"
