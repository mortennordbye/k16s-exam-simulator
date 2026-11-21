#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
apparmor_parser -r -W /etc/apparmor.d/k8s-deny-etc
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: deny-etc-pod, namespace: default}
spec:
  nodeName: controlplane
  containers:
  - name: deny-etc
    image: busybox:latest
    command: ["sleep", "3600"]
    securityContext:
      appArmorProfile: {type: Localhost, localhostProfile: k8s-deny-etc}
EOF
kubectl wait --for=condition=Ready pod/deny-etc-pod --timeout=90s
kubectl exec deny-etc-pod -c deny-etc -- sh -c 'echo test > /etc/blocked' > /opt/cks-apparmor/deny-etc-test.txt 2>&1
cat /opt/cks-apparmor/deny-etc-test.txt
