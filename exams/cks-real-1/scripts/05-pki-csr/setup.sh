#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

mkdir -p /opt/cks-pki

# Generate alice's private key for the student to use
if [[ ! -f /opt/cks-pki/alice.key ]]; then
  openssl genrsa -out /opt/cks-pki/alice.key 2048
  chmod 600 /opt/cks-pki/alice.key
fi
rm -f /opt/cks-pki/alice.csr /opt/cks-pki/alice.crt
kubectl delete csr alice --ignore-not-found >/dev/null

echo "Private key ready at /opt/cks-pki/alice.key: create alice.csr from it and get it signed"
