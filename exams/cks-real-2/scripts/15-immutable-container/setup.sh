#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create namespace immutable --dry-run=client -o yaml | kubectl apply -f -
kubectl -n immutable delete deployment frontend --ignore-not-found >/dev/null
kubectl -n immutable create deployment frontend --image=nginx:1.27-alpine --replicas=2 --port=80
echo "Environment ready: deployment frontend in namespace immutable"
