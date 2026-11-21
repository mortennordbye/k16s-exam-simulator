#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
m=/etc/kubernetes/manifests/kube-apiserver.yaml
grep -q -- '--profiling=false' $m || sed -i 's#^\(\s*\)- kube-apiserver$#&\n\1- --profiling=false#' $m
sleep 20
for i in $(seq 1 60); do
  ps -ewwo args | grep -E '^kube-apiserver ' | tr ' ' '\n' | grep -qx -- '--profiling=false' && kubectl get --raw=/readyz >/dev/null 2>&1 && break
  sleep 3
done
