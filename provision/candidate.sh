#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

log_step "Candidate user environment"

already_done "candidate" && { log_skip "candidate user"; exit 0; }

WORKER_COUNT="${K16S_WORKER_COUNT:-1}"
NET_BASE="${K16S_NET_BASE:-10.10.0}"
NODE_IP_START=11
CANDIDATE_PASS="${K16S_CANDIDATE_PASS:-k16s-$(openssl rand -hex 4)}"

if ! id candidate &>/dev/null; then
  useradd -m -s /bin/bash candidate
  log_ok "User 'candidate' created"
fi

echo "candidate:${CANDIDATE_PASS}" | chpasswd
echo "${CANDIDATE_PASS}" > /etc/k16s/candidate-password
chmod 600 /etc/k16s/candidate-password
log_info "Candidate password: ${CANDIDATE_PASS}"

mkdir -p /home/candidate/.kube
cp /root/.kube/config /home/candidate/.kube/config
chown -R candidate:candidate /home/candidate/.kube
log_ok "kubeconfig copied for candidate"

# CKS hub: like the real exam, "sudo -i" works on the task hosts. Host
# controlplane and host base are the same VM here, so sudo works on base too.
cat > /etc/sudoers.d/candidate <<'EOF'
candidate ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/candidate

su - candidate -c 'ssh-keygen -t ed25519 -N "" -f /home/candidate/.ssh/id_ed25519 -C candidate@controlplane' \
  2>/dev/null || true
CANDIDATE_PUBKEY=$(cat /home/candidate/.ssh/id_ed25519.pub)

# "ssh controlplane" logs in as candidate on this same VM (see the shell
# setup below): the candidate key must open its own account.
touch /home/candidate/.ssh/authorized_keys
grep -qxF "${CANDIDATE_PUBKEY}" /home/candidate/.ssh/authorized_keys \
  || echo "${CANDIDATE_PUBKEY}" >> /home/candidate/.ssh/authorized_keys
chmod 600 /home/candidate/.ssh/authorized_keys

for i in $(seq 1 "${WORKER_COUNT}"); do
  NAME="node0${i}"
  incus exec "${NAME}" -- bash -c "
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    touch /root/.ssh/authorized_keys
    grep -qxF '${CANDIDATE_PUBKEY}' /root/.ssh/authorized_keys \
      || echo '${CANDIDATE_PUBKEY}' >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
  "
  log_ok "Candidate SSH key installed on ${NAME}"
done

mkdir -p /home/candidate/.ssh
cat > /home/candidate/.ssh/config <<EOF
Host controlplane
  HostName 127.0.0.1
  User candidate
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR

EOF

for i in $(seq 1 "${WORKER_COUNT}"); do
  NAME="node0${i}"
  NODE_IP="${NET_BASE}.$((NODE_IP_START + i - 1))"
  cat >> /home/candidate/.ssh/config <<EOF
Host ${NAME}
  HostName ${NODE_IP}
  User root
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR

EOF
done
chmod 600 /home/candidate/.ssh/config
chown -R candidate:candidate /home/candidate/.ssh

# CKS hub: exam host flow. A local login (desktop terminal, web terminal) is
# host "base": no kubectl, like the real exam. "ssh controlplane" logs in to
# this same VM over ssh: then kubectl, alias k and completion work.
cat >> /home/candidate/.bashrc <<'BASHRC'

export EDITOR=vim
alias vi=vim
export ETCDCTL_API=3

if [[ -n "${SSH_CONNECTION:-}" ]]; then
  # host controlplane
  export KUBECONFIG=/home/candidate/.kube/config
  source /usr/share/bash-completion/bash_completion 2>/dev/null || true
  source <(kubectl completion bash) 2>/dev/null || true
  alias k=kubectl
  complete -o default -F __start_kubectl k 2>/dev/null || true
  PS1='\u@controlplane:\w\$ '
else
  # host base
  unset KUBECONFIG
  kubectl() {
    echo "kubectl is not available on host base. Use the ssh command of the task, for example: ssh controlplane" >&2
    return 127
  }
  PS1='\u@base:\w\$ '
fi

BASHRC

# root ("sudo -i" on controlplane): kubectl, alias k and completion.
sed -i '/^# >>> k16s exam shell >>>/,/^# <<< k16s exam shell <<</d' /root/.bashrc
cat >> /root/.bashrc <<'BASHRC'
# >>> k16s exam shell >>>
export KUBECONFIG=/root/.kube/config
source /usr/share/bash-completion/bash_completion 2>/dev/null || true
source <(kubectl completion bash) 2>/dev/null || true
alias k=kubectl
complete -o default -F __start_kubectl k 2>/dev/null || true
export EDITOR=vim
PS1='\u@controlplane:\w\$ '
# <<< k16s exam shell <<<
BASHRC

bash "$(dirname "$0")/yq.sh"

cat > /home/candidate/.vimrc <<'EOF'
set expandtab
set tabstop=2
set shiftwidth=2
set autoindent
set nu
EOF
chown candidate:candidate /home/candidate/.vimrc

cat > /home/candidate/.tmux.conf <<'EOF'
set -g mouse on
set -g history-limit 50000
set -g default-terminal "screen-256color"
bind | split-window -h
bind - split-window -v
EOF
chown candidate:candidate /home/candidate/.tmux.conf

touch /home/candidate/.hushlogin
chown candidate:candidate /home/candidate/.hushlogin

mark_done "candidate"
log_ok "Candidate environment configured (password: ${CANDIDATE_PASS})"
