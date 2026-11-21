#!/usr/bin/env bash
# Runs as root on controlplane. Checks the second cluster over ssh.
R() { ssh -o BatchMode=yes -o ConnectTimeout=5 cilium-cp "$@" 2>/dev/null; }
RK() { R "kubectl --kubeconfig /etc/kubernetes/admin.conf $*"; }

if [[ "$(R kubeadm version -o short)" != v1.37.* ]]; then
  echo "FAIL: kubeadm on cilium-cp is not v1.37 (got: $(R kubeadm version -o short))"
  exit 1
fi

APISERVER=$(RK "-n kube-system get pod kube-apiserver-cilium-cp -o jsonpath='{.spec.containers[0].image}'")
SERVER=$(RK "version -o json" | python3 -c 'import sys,json; print(json.load(sys.stdin)["serverVersion"]["gitVersion"])' 2>/dev/null)
if [[ "$SERVER" != v1.37.* || "$APISERVER" != *:v1.37.* ]]; then
  echo "FAIL: the control plane of cluster cilium does not run v1.37 (apiserver: ${SERVER:-unknown}, image: ${APISERVER:-unknown})"
  exit 1
fi

if [[ "$(RK "get node cilium-cp -o jsonpath='{.status.nodeInfo.kubeletVersion}'")" != v1.37.* ]]; then
  echo "FAIL: the kubelet on node cilium-cp is not v1.37"
  exit 1
fi

CLIENT=$(R "kubectl version --client -o json" | python3 -c 'import sys,json; print(json.load(sys.stdin)["clientVersion"]["gitVersion"])' 2>/dev/null)
if [[ "$CLIENT" != v1.37.* ]]; then
  echo "FAIL: kubectl on cilium-cp is not v1.37 (got: ${CLIENT:-unknown})"
  exit 1
fi

NODE=$(RK "get node cilium-cp -o jsonpath='{.spec.unschedulable}/{.status.conditions[?(@.type==\"Ready\")].status}'")
DNS=$(RK "-n kube-system get deploy coredns -o jsonpath='{.status.readyReplicas}'")
if [[ "$NODE" != "/True" || "${DNS:-0}" -lt 1 ]]; then
  echo "FAIL: node cilium-cp is not Ready and schedulable (uncordoned), or CoreDNS is not ready (node: $NODE, coredns ready: ${DNS:-0})"
  exit 1
fi

HELD=$(R apt-mark showhold | sort | tr '\n' ' ')
if [[ "$HELD" != *kubeadm* || "$HELD" != *kubectl* || "$HELD" != *kubelet* ]]; then
  echo "FAIL: kubeadm, kubelet and kubectl are not all on hold on cilium-cp (held: ${HELD:-none})"
  exit 1
fi

if ! R "grep -q 'cilium-cp' /opt/cks-upgrade/nodes.txt && grep -q 'v1\.37\.' /opt/cks-upgrade/nodes.txt"; then
  echo "FAIL: /opt/cks-upgrade/nodes.txt on cilium-cp does not hold the kubectl get nodes output with v1.37"
  exit 1
fi

echo "PASS: cluster cilium runs v1.37 (kubeadm, control plane, kubelet, kubectl) and node cilium-cp is uncordoned"
