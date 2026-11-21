#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
cat <<'EOF' | kubectl replace --force -f -
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
    volumeMounts:
    - name: db
      mountPath: /etc/db-secret
      readOnly: true
  volumes:
  - name: db
    secret:
      secretName: db-secret
EOF
kubectl -n orders wait --for=condition=Ready pod/app --timeout=60s
kubectl -n orders get secret legacy-token -o jsonpath='{.data.token}' | base64 -d > /opt/cks-secrets/legacy-token.txt
