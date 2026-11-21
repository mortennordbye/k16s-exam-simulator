#!/usr/bin/env bash
# CKS hub: run as root on the main VM (k16s) by "k16s-local" after both VMs
# are up. Makes host cilium-cp reachable: /etc/hosts, ssh config for root
# (setup and check scripts run "ssh cilium-cp ...") and for candidate
# ("ssh cilium-cp" from the exam terminal). The public keys were already
# added to cilium-cp by k16s-local. Idempotent.
#   usage: cilium-link.sh <cilium-cp IP>
set -euo pipefail
source "$(dirname "$0")/lib.sh"

IP="${1:?usage: cilium-link.sh <ip>}"

sed -i '/[[:space:]]cilium-cp$/d' /etc/hosts
echo "${IP}  cilium-cp" >> /etc/hosts

write_block() {   # file user
  local f="$1" user="$2"
  touch "${f}"
  sed -i '/^# >>> k16s cilium-cp >>>/,/^# <<< k16s cilium-cp <<</d' "${f}"
  cat >> "${f}" <<EOF
# >>> k16s cilium-cp >>>
Host cilium-cp
  HostName cilium-cp
  User ${user}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
  ConnectTimeout 5
# <<< k16s cilium-cp <<<
EOF
  chmod 600 "${f}"
}

mkdir -p /root/.ssh && chmod 700 /root/.ssh
write_block /root/.ssh/config root
if id candidate &>/dev/null; then
  install -d -o candidate -g candidate -m 700 /home/candidate/.ssh
  write_block /home/candidate/.ssh/config candidate
  chown candidate:candidate /home/candidate/.ssh/config
fi

ssh -o BatchMode=yes cilium-cp true || die "root cannot ssh to cilium-cp"
log_ok "root: ssh cilium-cp works"
if id candidate &>/dev/null; then
  su - candidate -c 'ssh -o BatchMode=yes cilium-cp true' || die "candidate cannot ssh to cilium-cp"
  log_ok "candidate: ssh cilium-cp works"
fi
