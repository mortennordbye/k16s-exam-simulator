#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p /opt/cks-static
kubectl create namespace static --dry-run=client -o yaml | kubectl apply -f -
cat > /opt/cks-static/reporting.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: reporting
  namespace: static
  labels:
    app: reporting
spec:
  hostPID: true
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.27-alpine
    ports:
    - containerPort: 8080
    securityContext:
      privileged: true
EOF
kubectl delete pod reporting -n static --ignore-not-found --now >/dev/null
kubectl apply -f /opt/cks-static/reporting.yaml
cat > /opt/cks-static/app.sh <<'EOF'
#!/bin/sh
exec curl -s https://example.com
EOF
cat > /opt/cks-static/Dockerfile <<'EOF'
FROM ubuntu:latest
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV DB_PASSWORD=Sup3rS3cret!
RUN useradd -u 10001 -m appuser
COPY app.sh /app/app.sh
USER root
CMD ["/app/app.sh"]
EOF
echo "Environment ready: /opt/cks-static/reporting.yaml (running) and /opt/cks-static/Dockerfile"
