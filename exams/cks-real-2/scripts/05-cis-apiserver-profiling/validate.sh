#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

ARGS=$(ps -ewwo args | grep -E '^kube-apiserver ' || true)
if [[ " $ARGS " != *" --profiling=false "* ]] || ! kubectl get --raw=/readyz >/dev/null 2>&1; then
  echo "FAIL: the running kube-apiserver does not use --profiling=false, or the API server is not ready"
  exit 1
fi

echo "PASS: kube-apiserver runs with --profiling=false"
