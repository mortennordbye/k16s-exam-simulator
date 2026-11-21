#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

mkdir -p /opt/cks-sbom
rm -f /opt/cks-sbom/nginx.spdx.json
kubectl create namespace sbom --dry-run=client -o yaml | kubectl apply -f -
for d in alpha:alpine:3.18.6 beta:alpine:3.19.1 gamma:alpine:3.20.3; do
  name=${d%%:*}; img=${d#*:}
  kubectl -n sbom create deployment "$name" --image="$img" --dry-run=client -o yaml -- sleep infinity | kubectl apply -f -
done
echo "Environment ready: deployments alpha, beta, gamma in namespace sbom"
