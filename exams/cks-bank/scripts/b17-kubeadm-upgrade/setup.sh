#!/usr/bin/env bash
# Runs as root on controlplane. The task works on the second cluster (cilium-cp).
set -eo pipefail
R() { ssh -o BatchMode=yes -o ConnectTimeout=5 cilium-cp "$@"; }

if ! R true; then
  echo "ERROR: host cilium-cp is not reachable. Build it with: make rebuild-cilium"
  exit 1
fi

R 'mkdir -p /opt/cks-upgrade && rm -f /opt/cks-upgrade/nodes.txt && chown candidate: /opt/cks-upgrade'

V=$(R "kubectl --kubeconfig /etc/kubernetes/admin.conf get node cilium-cp -o jsonpath='{.status.nodeInfo.kubeletVersion}'")
case "$V" in
  v1.36.*)
    # Reset a half-done earlier try: repository back to v1.36, packages held.
    R 'sed -i "s#/core:/stable:/v1.37/#/core:/stable:/v1.36/#" /etc/apt/sources.list.d/kubernetes.list
       apt-mark hold kubeadm kubelet kubectl >/dev/null
       kubectl --kubeconfig /etc/kubernetes/admin.conf uncordon cilium-cp >/dev/null 2>&1 || true'
    echo "Cluster cilium runs $V. Upgrade it to v1.37."
    ;;
  v1.37.*)
    # A cluster cannot go back to v1.36 within the setup time. Only the
    # nodes.txt step gives points now. To practise the full upgrade again,
    # build the second cluster again on the Mac: make rebuild-cilium
    echo "NOTE: cilium-cp already runs $V (upgraded in an earlier session)."
    echo "To practise the upgrade again, run 'make rebuild-cilium' on the Mac (about 6 min)."
    ;;
  *)
    echo "ERROR: cannot read the version of node cilium-cp (got: '$V')"
    exit 1
    ;;
esac
