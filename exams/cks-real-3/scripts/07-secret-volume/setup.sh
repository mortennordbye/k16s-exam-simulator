#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p /opt/cks-secrets
rm -f /opt/cks-secrets/legacy-token.txt
kubectl create namespace orders --dry-run=client -o yaml | kubectl apply -f -
kubectl -n orders create secret generic db-secret --from-literal=user=orders --from-literal=password=0rd3rsPa55 \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n orders create secret generic legacy-token --from-literal=token=lt-29f8c1d04e \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n orders delete pod app --ignore-not-found --now >/dev/null
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: orders
spec:
  containers:
  - name: app
    image: busybox:1.37
    command: ["sh", "-c", "sleep infinity"]
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef: {name: db-secret, key: user}
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef: {name: db-secret, key: password}
EOF
echo "Environment ready: pod app and secrets db-secret, legacy-token in namespace orders"
