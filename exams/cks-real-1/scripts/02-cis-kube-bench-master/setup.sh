#!/usr/bin/env bash
set -eo pipefail

mkdir -p /opt/cks3-cis
rm -f /opt/cks3-cis/kube-bench-master.txt

# Remove --profiling from controller-manager and scheduler so 1.3.2 and 1.4.1 FAIL.
for c in kube-controller-manager kube-scheduler; do
  m=/etc/kubernetes/manifests/$c.yaml
  if grep -q -- '--profiling' "$m"; then
    sed -i '/--profiling/d' "$m"
  fi
done

echo "Environment ready: run kube-bench for master checks and fix 1.3.2 and 1.4.1"
