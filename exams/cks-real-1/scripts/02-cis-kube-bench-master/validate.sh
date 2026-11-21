#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
F=/opt/cks3-cis/kube-bench-master.txt
flag() { local a; a=$(ps -ewwo args | grep -E "^$1 " || true); [[ " $a " == *" --profiling=false "* ]]; }
ready() { [[ "$(kubectl -n kube-system get pod "$1-controlplane" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" == "True" ]]; }

if [[ ! -s "$F" ]]; then
  echo "FAIL: $F is missing or empty"
  exit 1
fi

if ! grep -qE '^\[(PASS|FAIL|WARN|INFO)\] 1\.[1-4]\.' "$F"; then
  echo "FAIL: $F does not hold kube-bench master (control plane) output"
  exit 1
fi

if ! flag kube-controller-manager || ! ready kube-controller-manager; then
  echo "FAIL: 1.3.2: the running kube-controller-manager does not use --profiling=false, or its pod is not Ready"
  exit 1
fi

if ! flag kube-scheduler || ! ready kube-scheduler; then
  echo "FAIL: 1.4.1: the running kube-scheduler does not use --profiling=false, or its pod is not Ready"
  exit 1
fi

echo "PASS: kube-bench master output saved; controller-manager and scheduler run with --profiling=false"
