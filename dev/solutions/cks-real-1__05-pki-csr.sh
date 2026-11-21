#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
cd /opt/cks-pki
openssl req -new -key alice.key -out alice.csr -subj '/CN=alice/O=dev/O=ops'
kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata: {name: alice}
spec:
  request: $(base64 -w0 alice.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: [client auth]
EOF
kubectl certificate approve alice
for i in $(seq 1 20); do c=$(kubectl get csr alice -o jsonpath='{.status.certificate}'); [ -n "$c" ] && break; sleep 1; done
echo "$c" | base64 -d > /opt/cks-pki/alice.crt
