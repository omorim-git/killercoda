#!/bin/bash

# cpu-hog が起動していなければ起動してレイテンシ劣化を再現
if ! kubectl -n latency-demo get pods -l app=cpu-hog 2>/dev/null | grep -q Running; then
  echo "-> cpu-hog は起動していません。replicas=1 にスケールします。"
  kubectl apply -f /etc/kc_relay_web/40-cpuhog.yaml
  kubectl -n latency-demo scale deploy/cpu-hog --replicas=1
  kubectl -n latency-demo rollout status deploy/cpu-hog --timeout=120s || true
else
  echo "-> cpu-hog は既に起動中です（replicas=$REPLICAS, ready=$READY）"
fi