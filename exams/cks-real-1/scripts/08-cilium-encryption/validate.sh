#!/usr/bin/env bash
# Runs as root on controlplane. Checks Cilium on cilium-cp over ssh.
R() { ssh -o BatchMode=yes -o ConnectTimeout=5 cilium-cp "$@" 2>/dev/null; }
K="kubectl --kubeconfig /etc/kubernetes/admin.conf -n kube-system"

if [[ "$(R "$K get cm cilium-config -o jsonpath='{.data.enable-wireguard}'")" != "true" ]]; then
  echo "FAIL: the Cilium configuration (ConfigMap cilium-config) does not turn on WireGuard encryption"
  exit 1
fi

STATUS=$(R "$K exec ds/cilium -c cilium-agent -- cilium-dbg encrypt status")
if ! grep -q 'Encryption: Wireguard' <<< "$STATUS"; then
  echo "FAIL: the running Cilium agent does not use WireGuard encryption (restart the agent pods)"
  exit 1
fi

if ! R "grep -q 'Encryption: Wireguard' /opt/cks-cilium/encrypt-status.txt && grep -q 'cilium_wg0' /opt/cks-cilium/encrypt-status.txt"; then
  echo "FAIL: /opt/cks-cilium/encrypt-status.txt on cilium-cp does not hold the cilium-dbg encrypt status output with WireGuard"
  exit 1
fi

DS=$(R "$K get ds cilium -o jsonpath='{.status.desiredNumberScheduled}/{.status.numberReady}'")
OP=$(R "$K get deploy cilium-operator -o jsonpath='{.status.availableReplicas}'")
DNS=$(R "$K get deploy coredns -o jsonpath='{.status.readyReplicas}'")
IPAM=$(R "$K get cm cilium-config -o jsonpath='{.data.ipam}'")
if [[ "$DS" != "1/1" || "${OP:-0}" -lt 1 || "${DNS:-0}" -lt 1 || "$IPAM" != "kubernetes" ]]; then
  echo "FAIL: Cilium is not healthy or other settings changed (agent ready: $DS, operator: ${OP:-0}, coredns: ${DNS:-0}, ipam: ${IPAM:-unset})"
  exit 1
fi

echo "PASS: Cilium runs with WireGuard transparent encryption"
