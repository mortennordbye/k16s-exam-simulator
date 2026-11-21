#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl create namespace team-green --dry-run=client -o yaml | kubectl apply -f -
for s in db-creds api-token; do
  kubectl -n team-green delete secret "$s" --ignore-not-found >/dev/null
done
kubectl -n team-green create secret generic db-creds --from-literal=username=green --from-literal=password=Gr33nPassw0rd
kubectl -n team-green create secret generic api-token --from-literal=token=tok-7f3a9c21
mkdir -p /etc/kubernetes/enc
if grep -q -- '--encryption-provider-config' /etc/kubernetes/manifests/kube-apiserver.yaml; then
  echo "note: encryption at rest is already configured on this cluster"
fi
echo "Environment ready: namespace team-green with secrets db-creds and api-token"
