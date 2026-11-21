#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
cat > /var/lib/kubelet/seccomp/profiles/block-mkdir.json <<'EOF'
{"defaultAction": "SCMP_ACT_ALLOW", "syscalls": [{"names": ["mkdir", "mkdirat"], "action": "SCMP_ACT_ERRNO"}]}
EOF
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: seccomp-mkdir, namespace: default}
spec:
  nodeName: controlplane
  securityContext:
    seccompProfile: {type: Localhost, localhostProfile: profiles/block-mkdir.json}
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
EOF
kubectl wait --for=condition=Ready pod/seccomp-mkdir --timeout=90s
