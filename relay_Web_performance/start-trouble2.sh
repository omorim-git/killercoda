#!/bin/bash
set -euo pipefail

NS="latency-demo"
CPU_DEPLOY="cpu-hog"
CS_DEPLOY="cs"
CPU_YAML="/etc/kc_relay_web/40-cpuhog.yaml"
CS_YAML="/etc/kc_relay_web/50-cs.yaml"
ROLLOUT_TIMEOUT="120s"

echo "=== Stop CPU hog and start CS context-switch workload ==="

# 1) 確実にNamespaceがあることを確認
if ! kubectl get ns "${NS}" >/dev/null 2>&1; then
  echo "-> Namespace ${NS} が無いので作成します"
  kubectl create ns "${NS}"
fi

# 2) cpu-hog を停止（存在すれば）
if kubectl -n "${NS}" get deploy "${CPU_DEPLOY}" >/dev/null 2>&1; then
  echo "-> ${CPU_DEPLOY} を replicas=0 にスケールダウンします"
  kubectl -n "${NS}" scale deploy/"${CPU_DEPLOY}" --replicas=0 || true
  # rollout status はreplicas=0だと完了判定にならないことがあるため軽く待つだけ
  echo "-> ${CPU_DEPLOY} のPod終了を待機します"
  kubectl -n "${NS}" wait --for=delete pod -l app="${CPU_DEPLOY}" --timeout=60s || true
else
  echo "-> ${CPU_DEPLOY} のDeploymentは見つかりませんでした（スキップ）"
fi

# 3) cs の定義を適用
echo "-> CSワークロードのマニフェストを適用: ${CS_YAML}"
kubectl apply -f "${CS_YAML}"

# 4) cs を起動（replicas=1）
echo "-> ${CS_DEPLOY} を replicas=1 にスケールアップします"
kubectl -n "${NS}" scale deploy/"${CS_DEPLOY}" --replicas=1

# 5) 起動完了待ち
echo "-> ${CS_DEPLOY} のロールアウト完了を待機します（timeout=${ROLLOUT_TIMEOUT}）"
kubectl -n "${NS}" rollout status deploy/"${CS_DEPLOY}" --timeout="${ROLLOUT_TIMEOUT}" || true

# 6) 確認表示
echo "-> 現在のPod一覧:"
kubectl -n "${NS}" get pods -o wide -l app="${CS_DEPLOY}"
echo "-> 完了: cpu-hog 停止 / cs 起動"