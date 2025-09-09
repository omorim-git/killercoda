#!/bin/bash

# cpu-hog が起動していなければ起動してレイテンシ劣化を再現
REPLICAS=$(kubectl -n latency-demo get deploy cpu-hog -o jsonpath='{.status.replicas}' 2>/dev/null || echo 0)
READY=$(kubectl -n latency-demo get deploy cpu-hog -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [ "$REPLICAS" = "0" ] || [ "$READY" = "0" ]; then
  echo "-> cpu-hog は起動していません。replicas=1 にスケールします。"
  kubectl apply -f /etc/kc_relay_web/40-cpuhog.yaml
  kubectl -n latency-demo scale deploy/cpu-hog --replicas=1
  kubectl -n latency-demo rollout status deploy/cpu-hog --timeout=120s || true
else
  echo "-> cpu-hog は既に起動中です（replicas=$REPLICAS, ready=$READY）"
fi