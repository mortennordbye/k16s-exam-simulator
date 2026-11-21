#!/usr/bin/env bash
# Runs as root on controlplane. Turns WireGuard off on cilium-cp (the candidate
# turns it on). About 30 to 60 s when encryption was on.
set -eo pipefail
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 cilium-cp true; then
  echo "ERROR: host cilium-cp is not reachable. Build it with: make rebuild-cilium"
  exit 1
fi
ssh -o BatchMode=yes cilium-cp bash -s <<'EOF'
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p /opt/cks-cilium
rm -f /opt/cks-cilium/encrypt-status.txt
chown candidate: /opt/cks-cilium
V=$(kubectl -n kube-system get ds cilium -o jsonpath='{.spec.template.spec.containers[0].image}' | sed -E 's/.*:v([0-9.]+).*/\1/')
if [[ "$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}')" == "true" ]] \
   || kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg encrypt status 2>/dev/null | grep -q 'Encryption: Wireguard'; then
  cilium upgrade --version "$V" --reuse-values --set encryption.enabled=false >/dev/null
  # Helm does not undo a hand edit of the ConfigMap when its values did not
  # change, so set the key directly too.
  kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"false"}}' >/dev/null
  kubectl -n kube-system rollout restart ds/cilium >/dev/null
  kubectl -n kube-system rollout status ds/cilium --timeout=90s >/dev/null
fi
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=30s >/dev/null
EOF
echo "Cluster cilium: transparent encryption is off"
