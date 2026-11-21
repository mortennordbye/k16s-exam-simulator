#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
cat > /opt/cks-security/hardened.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: hardened, namespace: default}
spec:
  nodeName: controlplane
  securityContext:
    seccompProfile: {type: RuntimeDefault}
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      appArmorProfile: {type: Localhost, localhostProfile: k8s-no-proc-write}
EOF
kubectl apply -f /opt/cks-security/hardened.yaml
kubectl wait --for=condition=Ready pod/hardened --timeout=90s
