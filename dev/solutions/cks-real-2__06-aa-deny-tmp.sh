#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
apparmor_parser -r -W /opt/cks2-apparmor/profile
NAME=$(grep -oP '^profile \K\S+' /opt/cks2-apparmor/profile)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata: {name: hosts-check, namespace: apparmor-hosts}
spec:
  nodeName: controlplane
  containers:
  - name: app
    image: busybox:1.37
    command: ["sleep", "3600"]
    securityContext:
      appArmorProfile: {type: Localhost, localhostProfile: $NAME}
EOF
kubectl -n apparmor-hosts wait --for=condition=Ready pod/hosts-check --timeout=90s
