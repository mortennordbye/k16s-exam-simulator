#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p /opt/cks-ingress
if [[ ! -f /opt/cks-ingress/shop.crt ]]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj "/CN=shop.k16s.local" \
    -addext "subjectAltName=DNS:shop.k16s.local" \
    -keyout /opt/cks-ingress/shop.key -out /opt/cks-ingress/shop.crt 2>/dev/null
fi
kubectl create namespace shop --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop create deployment shop --image=nginx:1.27-alpine --port=80 --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop expose deployment shop --name=shop-svc --port=80 --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop delete ingress shop-ingress --ignore-not-found >/dev/null
kubectl -n shop delete secret shop-tls --ignore-not-found >/dev/null
echo "Environment ready: namespace shop, service shop-svc, cert files in /opt/cks-ingress"
