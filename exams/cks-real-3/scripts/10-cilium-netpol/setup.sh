#!/usr/bin/env bash
# Runs as root on controlplane. The task works on the second cluster (cilium-cp).
set -eo pipefail
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 cilium-cp true; then
  echo "ERROR: host cilium-cp is not reachable. Build it with: make rebuild-cilium"
  exit 1
fi
ssh -o BatchMode=yes cilium-cp bash -s <<'EOF'
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create namespace team-blue --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n team-blue delete ciliumnetworkpolicy --all >/dev/null
kubectl -n team-blue delete networkpolicy --all >/dev/null
for a in frontend backend database other; do
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata: {name: $a, namespace: team-blue}
spec:
  replicas: 1
  selector: {matchLabels: {app: $a}}
  template:
    metadata: {labels: {app: $a}}
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: $a, namespace: team-blue}
spec:
  selector: {app: $a}
  ports: [{port: 80}]
YAML
done
kubectl -n team-blue rollout status deployment --timeout=90s >/dev/null
EOF
echo "Namespace team-blue on cluster cilium is ready: deployments frontend, backend, database, other (no policies)"
