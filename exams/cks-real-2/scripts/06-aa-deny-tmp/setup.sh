#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl create namespace apparmor-hosts --dry-run=client -o yaml | kubectl apply -f -
kubectl -n apparmor-hosts delete pod hosts-check --ignore-not-found --now >/dev/null
mkdir -p /opt/cks2-apparmor

cat > /opt/cks2-apparmor/profile <<'EOF'
#include <tunables/global>

profile k16s-deny-tmp flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  file,
  network,
  capability,
  mount,
  umount,
  signal,
  ptrace,
  pivot_root,

  deny /tmp/** w,
}
EOF

# The candidate loads it: unload a copy from an earlier run.
apparmor_parser -R /opt/cks2-apparmor/profile >/dev/null 2>&1 || true

echo "Profile file ready at /opt/cks2-apparmor/profile (not loaded); namespace apparmor-hosts ready"
