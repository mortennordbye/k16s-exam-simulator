#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl delete pod seccomp-mkdir --ignore-not-found --now >/dev/null
mkdir -p /var/lib/kubelet/seccomp/profiles
rm -f /var/lib/kubelet/seccomp/profiles/block-mkdir.json
echo "Directory /var/lib/kubelet/seccomp/profiles/ is ready: create your profile there"
