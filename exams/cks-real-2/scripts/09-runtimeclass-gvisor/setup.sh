#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p /opt/cks-gvisor
rm -f /opt/cks-gvisor/dmesg.txt
kubectl delete runtimeclass gvisor --ignore-not-found >/dev/null
kubectl create namespace sandbox --dry-run=client -o yaml | kubectl apply -f -
for d in payments ledger; do
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $d
  namespace: sandbox
spec:
  replicas: 2
  selector:
    matchLabels: {app: $d}
  template:
    metadata:
      labels: {app: $d}
    spec:
      nodeSelector:
        kubernetes.io/hostname: controlplane
      containers:
      - name: app
        image: nginx:1.27-alpine
EOF
done
# reset an earlier attempt
kubectl -n sandbox patch deployment payments --type=json -p='[{"op":"remove","path":"/spec/template/spec/runtimeClassName"}]' >/dev/null 2>&1 || true
echo "Environment ready: deployments payments and ledger in namespace sandbox"
