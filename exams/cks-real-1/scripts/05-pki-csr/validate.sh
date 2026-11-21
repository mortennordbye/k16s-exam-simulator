#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

CSR="/opt/cks-pki/alice.csr"

if [[ ! -f "$CSR" ]]; then
  echo "FAIL: CSR not found at $CSR"
  exit 1
fi

# Verify it's a valid CSR
if ! openssl req -in "$CSR" -noout 2>/dev/null; then
  echo "FAIL: $CSR is not a valid PEM-encoded CSR"
  exit 1
fi

if [[ "$(openssl req -in "$CSR" -noout -pubkey 2>/dev/null | openssl pkey -pubin -outform der 2>/dev/null | sha256sum)" != "$(openssl pkey -in /opt/cks-pki/alice.key -pubout -outform der 2>/dev/null | sha256sum)" ]]; then
  echo "FAIL: $CSR was not created from /opt/cks-pki/alice.key"
  exit 1
fi

SUBJECT=$(openssl req -in "$CSR" -noout -subject 2>/dev/null)

# CN=alice
if ! echo "$SUBJECT" | grep -q "CN\s*=\s*alice\|CN = alice"; then
  echo "FAIL: CSR subject missing CN=alice (got: $SUBJECT)"
  exit 1
fi

# O=dev
if ! echo "$SUBJECT" | grep -q "O\s*=\s*dev\b\|O = dev"; then
  echo "FAIL: CSR subject missing O=dev (got: $SUBJECT)"
  exit 1
fi

# O=ops
if ! echo "$SUBJECT" | grep -q "O\s*=\s*ops\b\|O = ops"; then
  echo "FAIL: CSR subject missing O=ops (got: $SUBJECT)"
  exit 1
fi

if [[ "$(kubectl get csr alice -o jsonpath='{.spec.signerName}/{.status.conditions[?(@.type=="Approved")].status}' 2>/dev/null)" != "kubernetes.io/kube-apiserver-client/True" ]]; then
  echo "FAIL: CertificateSigningRequest alice with signer kubernetes.io/kube-apiserver-client is missing or not approved"
  exit 1
fi

CRT=/opt/cks-pki/alice.crt
if ! openssl verify -CAfile /etc/kubernetes/pki/ca.crt "$CRT" >/dev/null 2>&1 ||
   ! openssl x509 -in "$CRT" -noout -subject 2>/dev/null | grep -q "CN *= *alice"; then
  echo "FAIL: $CRT is missing, not signed by the cluster CA, or its subject is not CN=alice"
  exit 1
fi

echo "PASS: alice.csr has subject CN=alice O=dev O=ops, CSR alice is approved and alice.crt is issued"
