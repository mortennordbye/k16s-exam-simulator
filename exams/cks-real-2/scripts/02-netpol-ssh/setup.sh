#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl create namespace netpol-ssh --dry-run=client -o yaml | kubectl apply -f -
kubectl -n netpol-ssh run sshd --image=alpine --labels=app=sshd \
  --command --dry-run=client -o yaml -- sh -c 'sleep 3600' | kubectl apply -f -

kubectl -n netpol-ssh delete networkpolicy allow-ssh-office --ignore-not-found >/dev/null
mkdir -p /opt/cks-netpol
rm -f /opt/cks-netpol/allow-ssh-office.yaml
echo "Environment ready: namespace netpol-ssh with sshd pod"
