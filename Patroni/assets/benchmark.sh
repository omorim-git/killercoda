#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

label="${1:-manual}"
duration="${2:-20}"
rate="${3:-300}"
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
wait_timeout="$((duration + 180))"
keep_artifacts=0

job_pod_name() {
  kubectl get pods -n "$K8S_NAMESPACE" -l job-name="$job_name" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

job_phase() {
  local pod_name

  pod_name="$(job_pod_name)"
  if [[ -z "$pod_name" ]]; then
    echo "NotCreated"
    return 0
  fi

  kubectl get pod -n "$K8S_NAMESPACE" "$pod_name" -o jsonpath='{.status.phase}' 2>/dev/null || true
}

job_waiting_reason() {
  local pod_name

  pod_name="$(job_pod_name)"
  if [[ -z "$pod_name" ]]; then
    return 0
  fi

  kubectl get pod -n "$K8S_NAMESPACE" "$pod_name" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true
}

print_job_debug() {
  local pod_name

  keep_artifacts=1
  pod_name="$(job_pod_name)"
  echo "== k6 job debug ==" >&2
  kubectl get job -n "$K8S_NAMESPACE" "$job_name" -o wide >&2 || true
  if [[ -n "$pod_name" ]]; then
    kubectl get pod -n "$K8S_NAMESPACE" "$pod_name" -o wide >&2 || true
    kubectl describe pod -n "$K8S_NAMESPACE" "$pod_name" >&2 || true
    kubectl logs -n "$K8S_NAMESPACE" "$pod_name" >&2 || true
  fi
}

cleanup() {
  local exit_code="${1:-0}"

  rm -f "$script_file" "$job_file"

  if (( keep_artifacts == 1 || exit_code != 0 )); then
    echo "[benchmark] preserving job artifacts for debugging: job/${job_name}" >&2
    return 0
  fi

  kubectl delete configmap "${job_name}-script" -n "$K8S_NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete job "$job_name" -n "$K8S_NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true
}

trap 'cleanup $?' EXIT

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
  echo "[benchmark] waiting for job/${job_name} to complete (timeout=${wait_timeout}s)"

  started_at="$(date +%s)"
  next_status_at="$started_at"
  while true; do
    if kubectl get job -n "$K8S_NAMESPACE" "$job_name" -o jsonpath='{.status.succeeded}' 2>/dev/null | grep -qx '1'; then
      break
    fi

    if kubectl get job -n "$K8S_NAMESPACE" "$job_name" -o jsonpath='{.status.failed}' 2>/dev/null | grep -Eq '^[1-9][0-9]*$'; then
      echo "[benchmark] job failed" >&2
      print_job_debug
      exit 1
    fi

    now="$(date +%s)"
    elapsed="$((now - started_at))"
    if (( elapsed >= wait_timeout )); then
      echo "[benchmark] timed out after ${wait_timeout}s" >&2
      print_job_debug
      exit 1
    fi

    if (( now >= next_status_at )); then
      phase="$(job_phase)"
      reason="$(job_waiting_reason)"
      echo "[benchmark] elapsed=${elapsed}s phase=${phase:-unknown} reason=${reason:-none}"
      case "$reason" in
        ErrImagePull|ImagePullBackOff|CreateContainerConfigError|CreateContainerError|CrashLoopBackOff|InvalidImageName)
          echo "[benchmark] pod is stuck in ${reason}" >&2
          print_job_debug
          exit 1
          ;;
      esac
      next_status_at="$((now + 5))"
    fi

    sleep 1
  done

  kubectl logs -n "$K8S_NAMESPACE" "job/${job_name}"
} | tee "$outfile"

echo "Saved: $outfile"
