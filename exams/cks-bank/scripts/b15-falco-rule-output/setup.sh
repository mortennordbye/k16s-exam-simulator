#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

# Falco is installed by provision/profiles/cks.sh (modern eBPF, service falco).
if ! command -v falco >/dev/null || [[ ! -f /etc/systemd/system/falco.service ]]; then
  echo "falco is not installed: run provision/profiles/cks.sh" >&2
  exit 1
fi

K=/var/lib/k16s/tasks
mkdir -p "$K" /var/log/falco
# Keep a clean copy of /etc/falco from the first run; reset to it on every setup.
[[ -d "$K/falco-etc.orig" ]] || cp -a /etc/falco "$K/falco-etc.orig"
rm -rf /etc/falco && cp -a "$K/falco-etc.orig" /etc/falco
rm -f /var/log/falco/alerts.log
systemctl restart falco
kubectl create namespace falco-lab --dry-run=client -o yaml | kubectl apply -f -
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: probe
  namespace: falco-lab
spec:
  nodeName: controlplane
  containers:
  - name: probe
    image: busybox:1.37
    command: ["sleep", "infinity"]
EOF
echo "Environment ready: Falco runs with its default configuration, pod falco-lab/probe"
