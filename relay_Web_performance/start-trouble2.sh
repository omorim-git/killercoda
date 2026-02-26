#!/bin/bash
set -euo pipefail

NS="latency-demo"
CPU_DEPLOY="cpu-hog"
CS_DEPLOY="cs"
CS_YAML="/etc/kc_relay_web/50-cs.yaml"
STEP3_READY_FILE="/tmp/step3-trouble-started"

echo "=== Switch to Step3 trouble state ==="
rm -f "${STEP3_READY_FILE}"

if ! kubectl get ns "${NS}" >/dev/null 2>&1; then
  echo "-> Namespace ${NS} が無いため作成します"
  kubectl create ns "${NS}"
fi

if kubectl -n "${NS}" get deploy "${CPU_DEPLOY}" >/dev/null 2>&1; then
  echo "-> ${CPU_DEPLOY} を replicas=0 に変更します（終了待機なし）"
  kubectl -n "${NS}" scale deploy/"${CPU_DEPLOY}" --replicas=0 || true
else
  echo "-> ${CPU_DEPLOY} は見つかりません（スキップ）"
fi

echo "-> CSワークロードを適用します: ${CS_YAML}"
kubectl apply -f "${CS_YAML}"

echo "-> ${CS_DEPLOY} を replicas=2 に変更します（起動待機なし）"
kubectl -n "${NS}" scale deploy/"${CS_DEPLOY}" --replicas=2

touch "${STEP3_READY_FILE}"
echo "-> Step3 切替コマンド完了（cpu-hog 停止指示 / cs 起動指示）"
