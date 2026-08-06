#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

label="${1:-manual}"
duration="${2:-20}"
rate="${3:-120}"
pre_allocated_vus="${4:-40}"
max_vus="${5:-120}"
safe_label="$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')"

results_dir="${LAB_HOME_DIR}/results"
mkdir -p "$results_dir"

timestamp="$(date +%Y%m%d-%H%M%S)"
outfile="${results_dir}/${timestamp}-${label}.log"
job_name="${K6_JOB_PREFIX}-${safe_label}-${timestamp}"
script_file="$(mktemp)"
job_file="$(mktemp)"

cleanup() {
  rm -f "$script_file" "$job_file"
  kubectl delete configmap "${job_name}-script" -n "$K8S_NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete job "$job_name" -n "$K8S_NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true
}

trap cleanup EXIT

if ! api_healthy; then
  echo "API is not healthy: $(api_health_url)" >&2
  exit 1
fi

cat >"$script_file" <<EOF
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  noConnectionReuse: true,
  thresholds: {
    http_req_failed: ['rate<0.01'],
  },
  scenarios: {
    tat_steady: {
      executor: 'constant-arrival-rate',
      rate: ${rate},
      timeUnit: '1s',
      duration: '${duration}s',
      preAllocatedVUs: ${pre_allocated_vus},
      maxVUs: ${max_vus},
    },
  },
};

export default function () {
  const response = http.get('http://$(controlplane_ip):${API_PORT}${API_TXN_PATH}', {
    headers: {
      Connection: 'close',
    },
    tags: {
      endpoint: 'txn',
      profile: '${label}',
    },
  });

  check(response, {
    'status is 200': (r) => r.status === 200,
  });
}
EOF

kubectl create configmap "${job_name}-script" -n "$K8S_NAMESPACE" --from-file=script.js="$script_file" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

cat >"$job_file" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job_name}
  namespace: ${K8S_NAMESPACE}
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: $(worker_node)
      containers:
        - name: k6
          image: grafana/k6:latest
          imagePullPolicy: IfNotPresent
          command: ["k6", "run", "/scripts/script.js"]
          volumeMounts:
            - name: script
              mountPath: /scripts
      volumes:
        - name: script
          configMap:
            name: ${job_name}-script
EOF

kubectl apply -f "$job_file" >/dev/null

{
  echo "[benchmark] label=${label} duration=${duration}s rate=${rate}/s preAllocatedVUs=${pre_allocated_vus} maxVUs=${max_vus}"
  kubectl wait --for=condition=complete -n "$K8S_NAMESPACE" "job/${job_name}" --timeout="$((duration + 180))s" >/dev/null
  kubectl logs -n "$K8S_NAMESPACE" "job/${job_name}"
} | tee "$outfile"

echo "Saved: $outfile"
