#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
EOF
kubectl -n sandbox patch deployment payments -p '{"spec":{"template":{"spec":{"runtimeClassName":"gvisor"}}}}'
kubectl -n sandbox rollout status deployment payments --timeout=90s
kubectl -n sandbox exec deploy/payments -- dmesg > /opt/cks-gvisor/dmesg.txt
