#!/bin/bash
set -euo pipefail

export OWNER='omorim-git'
export WEB_IMAGE="ghcr.io/${OWNER}/webapp-av:0.1"
export OR_IMAGE="ghcr.io/${OWNER}/openresty-av:0.1"

kubectl label node controlplane node-purpose=web --overwrite
export WEB_IMAGE OR_IMAGE
# envsubst '${WEB_IMAGE} ${OR_IMAGE}' < k8s/all-cpucheck.tmpl.yaml | kubectl apply -f -

# kubectl -n demo rollout status deploy/clamav
# kubectl -n demo rollout status deploy/web
# kubectl -n demo rollout status deploy/reverse-proxy-av
# kubectl -n demo get pods -o wide -n demo

# 準備完了表示
touch /tmp/background-finished