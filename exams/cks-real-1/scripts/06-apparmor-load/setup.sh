#!/usr/bin/env bash
set -eo pipefail

export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl delete pod deny-etc-pod --ignore-not-found --now >/dev/null
rm -f /opt/cks-apparmor/deny-etc-test.txt
# Unload a copy from an earlier run: the candidate loads it.
if [[ -f /etc/apparmor.d/k8s-deny-etc ]]; then apparmor_parser -R /etc/apparmor.d/k8s-deny-etc >/dev/null 2>&1 || true; fi

# Create the AppArmor profile file for the student to load — do NOT load it.
cat > /etc/apparmor.d/k8s-deny-etc <<'EOF'
#include <tunables/global>

profile k8s-deny-etc flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  file,
  network,
  capability,
  mount,
  umount,
  signal,
  ptrace,
  pivot_root,

  deny /etc/** w,
}
EOF

mkdir -p /opt/cks-apparmor
echo "Profile file written to /etc/apparmor.d/k8s-deny-etc — load it with: apparmor_parser -r -W /etc/apparmor.d/k8s-deny-etc"
