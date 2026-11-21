#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create namespace ci --dry-run=client -o yaml | kubectl apply -f -
kubectl -n ci create serviceaccount deployer --dry-run=client -o yaml | kubectl apply -f -
kubectl -n ci patch serviceaccount deployer --type=json -p '[{"op":"remove","path":"/automountServiceAccountToken"}]' >/dev/null 2>&1 || true
kubectl create clusterrolebinding deployer-admin --clusterrole=cluster-admin --serviceaccount=ci:deployer \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n ci delete rolebinding deployer-rb --ignore-not-found >/dev/null
kubectl -n ci delete role deployer-role --ignore-not-found >/dev/null
kubectl -n ci delete deployment ci-runner --ignore-not-found >/dev/null
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ci-runner
  namespace: ci
spec:
  replicas: 1
  selector:
    matchLabels: {app: ci-runner}
  template:
    metadata:
      labels: {app: ci-runner}
    spec:
      serviceAccountName: deployer
      containers:
      - name: runner
        image: busybox:1.37
        command: ["sleep", "infinity"]
EOF
echo "Environment ready: ServiceAccount ci/deployer with cluster-admin, deployment ci-runner"
