#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl create namespace scan --dry-run=client -o yaml | kubectl apply -f -
pod() {
  kubectl -n scan run "$1" --image="$2" --labels="app=$1" --restart=Always \
    --dry-run=client -o yaml $3 | kubectl apply -f -
}
pod web     nginx:1.14.0
pod cache   redis:5.0.0
pod proxy   httpd:2.4.39
pod api     registry.k8s.io/pause:3.10
pod tools   busybox:1.37 "--command -- sleep infinity"
echo "Environment ready: 5 pods in namespace scan"
