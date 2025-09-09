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
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml \
	&& kubectl -n kube-system patch deploy/metrics-server --type='json' -p='[
	  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
	  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP"}
	]' \
	&& kubectl -n kube-system rollout status deploy/metrics-server \
	&& kubectl wait --for=condition=Available --timeout=120s apiservice/v1beta1.metrics.k8s.io \
    && for i in $(seq 1 10); do kubectl top nodes && break || { echo "metrics not ready yet; retry $i/10"; sleep 3; }; done

echo "[5/5] 準備完了"
echo "- Webページを開いて通常時の性能を確認してください。"
