#!/usr/bin/env bash
# Runs as root on controlplane; does the work on cilium-cp over ssh.
ssh cilium-cp bash -s <<'EOF'
export KUBECONFIG=/etc/kubernetes/admin.conf
V=$(kubectl -n kube-system get ds cilium -o jsonpath='{.spec.template.spec.containers[0].image}' | sed -E 's/.*:v([0-9.]+).*/\1/')
cilium upgrade --version "$V" --reuse-values --set encryption.enabled=true --set encryption.type=wireguard
kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg encrypt status > /opt/cks-cilium/encrypt-status.txt
cat /opt/cks-cilium/encrypt-status.txt
EOF
