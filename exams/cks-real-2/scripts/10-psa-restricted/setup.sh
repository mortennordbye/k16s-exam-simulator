#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create namespace secure-apps --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace secure-apps pod-security.kubernetes.io/enforce- pod-security.kubernetes.io/warn- \
  pod-security.kubernetes.io/enforce-version- pod-security.kubernetes.io/warn-version- >/dev/null 2>&1 || true
kubectl -n secure-apps delete deployment web --ignore-not-found >/dev/null
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: secure-apps
spec:
  replicas: 2
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web}
    spec:
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
EOF
echo "Environment ready: deployment web in namespace secure-apps"
