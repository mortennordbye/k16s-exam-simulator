#!/usr/bin/env bash
# Runs as root on controlplane; does the work on cilium-cp over ssh.
ssh cilium-cp bash -s <<'EOF'
set -e
export KUBECONFIG=/etc/kubernetes/admin.conf
export DEBIAN_FRONTEND=noninteractive
sed -i 's#/core:/stable:/v1.36/#/core:/stable:/v1.37/#' /etc/apt/sources.list.d/kubernetes.list
apt-get update -q
V=$(apt-cache madison kubeadm | awk '{print $3}' | grep '^1\.37\.' | sort -V | tail -1)
echo "target package version: $V"
apt-mark unhold kubeadm
apt-get install -y -q kubeadm="$V"
apt-mark hold kubeadm
kubeadm upgrade plan >/dev/null
kubeadm upgrade apply -y "v${V%%-*}"
kubectl drain cilium-cp --ignore-daemonsets --delete-emptydir-data --timeout=180s
apt-mark unhold kubelet kubectl
apt-get install -y -q kubelet="$V" kubectl="$V"
apt-mark hold kubelet kubectl
systemctl daemon-reload
systemctl restart kubelet
for i in $(seq 1 60); do kubectl get nodes >/dev/null 2>&1 && break; sleep 2; done
kubectl uncordon cilium-cp
kubectl wait --for=condition=Ready node/cilium-cp --timeout=180s
kubectl -n kube-system rollout status deploy/coredns --timeout=180s
kubectl get nodes > /opt/cks-upgrade/nodes.txt
cat /opt/cks-upgrade/nodes.txt
EOF
