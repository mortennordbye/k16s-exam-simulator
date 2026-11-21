#!/usr/bin/env bash
set -eo pipefail

# Remove --profiling flag if already set so candidate must add it
if grep -q '\-\-profiling' /etc/kubernetes/manifests/kube-apiserver.yaml; then
  sed -i '/--profiling/d' /etc/kubernetes/manifests/kube-apiserver.yaml
fi

echo "Environment ready: add --profiling=false to the kube-apiserver manifest"
