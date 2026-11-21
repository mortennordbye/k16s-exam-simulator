#!/usr/bin/env bash
# CKS hub: provision the second exam cluster "cilium-cp" (Lima instance
# k16s-cilium). One kubeadm node, Kubernetes v1.36 (one minor below the main
# cluster, for the kubeadm upgrade task), Cilium with WireGuard encryption.
#
# Runs as root inside the k16s-cilium VM:
#   sudo env K16S_K8S_VERSION=1.36 bash ~/k16s/provision/cilium-cp.sh
# Idempotent: each step has a marker in /var/lib/k16s/markers.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

export K16S_K8S_VERSION="${K16S_K8S_VERSION:-1.36}"
CILIUM_VERSION="${K16S_CILIUM_VERSION:-1.20.5}"
CILIUM_CLI_VERSION="${K16S_CILIUM_CLI_VERSION:-v0.20.3}"
NODE_NAME="cilium-cp"
POD_CIDR="10.20.0.0/16"
SVC_CIDR="10.96.0.0/12"

[[ "${EUID}" -eq 0 ]] || die "Must run as root"
mkdir -p /var/lib/k16s/markers /etc/k16s

log_step "cilium-cp: host name and swap"
hostnamectl set-hostname "${NODE_NAME}"
grep -q " ${NODE_NAME}$" /etc/hosts || echo "127.0.1.1  ${NODE_NAME}" >> /etc/hosts
swapoff -a
sed -i '/\bswap\b/d' /etc/fstab
log_ok "host name ${NODE_NAME}, swap off"

bash "${SCRIPT_DIR}/kernel.sh"
bash "${SCRIPT_DIR}/containerd.sh"   # also routes Docker Hub through mirror.gcr.io
bash "${SCRIPT_DIR}/kubeadm.sh"      # v${K16S_K8S_VERSION}, packages held
bash "${SCRIPT_DIR}/yq.sh"

# ── kubeadm init ────────────────────────────────────────────────────────────
log_step "cilium-cp: kubeadm init"
if already_done "cilium-init"; then
  log_skip "kubeadm init"
else
  NODE_IP=$(ip route get 8.8.8.8 | grep -oP 'src \K[^ ]+')
  K8S_FULL=$(kubeadm version -o short)
  cat > /etc/k16s/kubeadm-init.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${NODE_IP}
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  name: ${NODE_NAME}
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: "${K8S_FULL}"
clusterName: cilium
apiServer:
  certSANs: ["${NODE_NAME}", "${NODE_IP}"]
networking:
  podSubnet: "${POD_CIDR}"
  serviceSubnet: "${SVC_CIDR}"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF
  kubeadm init --config /etc/k16s/kubeadm-init.yaml 2>&1 | tee /var/log/kubeadm-init.log
  mkdir -p /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config
  chmod 600 /root/.kube/config
  KUBECONFIG=/root/.kube/config kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true
  mark_done "cilium-init"
  log_ok "kubeadm init done (${K8S_FULL}, node ${NODE_NAME}, untainted)"
fi
export KUBECONFIG=/root/.kube/config

# ── Cilium (cilium CLI, pinned) ─────────────────────────────────────────────
log_step "cilium-cp: Cilium ${CILIUM_VERSION} with WireGuard"
if ! cilium version --client 2>/dev/null | grep -q "cilium-cli: ${CILIUM_CLI_VERSION}"; then
  ARCH=$(dpkg --print-architecture)
  TMP=$(mktemp -d)
  curl -fsSL --retry 3 -o "${TMP}/cilium.tgz" \
    "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz"
  curl -fsSL --retry 3 -o "${TMP}/cilium.tgz.sha256sum" \
    "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz.sha256sum"
  (cd "${TMP}" && sed "s#cilium-linux-${ARCH}.tar.gz#cilium.tgz#" cilium.tgz.sha256sum | sha256sum -c - >/dev/null) \
    || die "cilium CLI checksum mismatch"
  tar -xzf "${TMP}/cilium.tgz" -C /usr/local/bin cilium
  rm -rf "${TMP}"
  log_ok "cilium CLI ${CILIUM_CLI_VERSION} installed"
fi
if already_done "cilium-cni"; then
  log_skip "Cilium install"
else
  cilium install --version "${CILIUM_VERSION}" \
    --set ipam.mode=kubernetes \
    --set operator.replicas=1 \
    --set encryption.enabled=true \
    --set encryption.type=wireguard
  cilium status --wait --wait-duration 6m
  kubectl -n kube-system wait --for=condition=Available deploy/coredns --timeout=180s
  mark_done "cilium-cni"
  log_ok "Cilium ${CILIUM_VERSION} ready"
fi
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg encrypt status 2>/dev/null | sed 's/^/  /' || true

# ── Exam users: root and candidate get kubectl, alias k, completion ────────
log_step "cilium-cp: exam shell for root and candidate"
if ! id candidate &>/dev/null; then
  useradd -m -s /bin/bash candidate
fi
cat > /etc/sudoers.d/candidate <<'EOF'
candidate ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/candidate
install -d -o candidate -g candidate -m 700 /home/candidate/.kube /home/candidate/.ssh
install -o candidate -g candidate -m 600 /etc/kubernetes/admin.conf /home/candidate/.kube/config
touch /home/candidate/.ssh/authorized_keys
chown candidate:candidate /home/candidate/.ssh/authorized_keys
chmod 600 /home/candidate/.ssh/authorized_keys
touch /home/candidate/.hushlogin
chown candidate:candidate /home/candidate/.hushlogin

for RC in /root/.bashrc /home/candidate/.bashrc; do
  sed -i '/^# >>> k16s exam shell >>>/,/^# <<< k16s exam shell <<</d' "${RC}"
  cat >> "${RC}" <<'BASHRC'
# >>> k16s exam shell >>>
source /usr/share/bash-completion/bash_completion 2>/dev/null || true
source <(kubectl completion bash) 2>/dev/null || true
alias k=kubectl
complete -o default -F __start_kubectl k 2>/dev/null || true
export EDITOR=vim
PS1='\u@cilium-cp:\w\$ '
# <<< k16s exam shell <<<
BASHRC
done
cat > /home/candidate/.vimrc <<'EOF'
set expandtab
set tabstop=2
set shiftwidth=2
set autoindent
EOF
chown candidate:candidate /home/candidate/.vimrc
mkdir -p /root/.ssh && chmod 700 /root/.ssh && touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
log_ok "root and candidate: kubectl, alias k, completion, yq"

echo ""
kubectl get nodes -o wide
log_ok "cilium-cp ready"
