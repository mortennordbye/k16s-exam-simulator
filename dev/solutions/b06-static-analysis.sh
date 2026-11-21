#!/usr/bin/env bash
# Reference solution for b06-static-analysis
export KUBECONFIG=/etc/kubernetes/admin.conf
cat > /opt/cks-static/reporting.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: reporting
  namespace: static
  labels:
    app: reporting
spec:
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.27-alpine
    ports:
    - containerPort: 8080
    resources:
      limits:
        memory: 128Mi
    securityContext:
      runAsNonRoot: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF
kubectl replace --force -f /opt/cks-static/reporting.yaml
kubectl -n static wait --for=condition=Ready pod/reporting --timeout=60s
sed -i -e 's/^FROM ubuntu:latest/FROM ubuntu:24.04/' -e '/DB_PASSWORD/d' -e 's/^USER root/USER appuser/' /opt/cks-static/Dockerfile
