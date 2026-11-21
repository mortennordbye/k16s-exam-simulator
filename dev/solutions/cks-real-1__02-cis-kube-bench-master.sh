#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kube-bench run --targets master 2>/dev/null > /opt/cks3-cis/kube-bench-master.txt
grep -E '^\[FAIL\] (1\.3\.2|1\.4\.1)' /opt/cks3-cis/kube-bench-master.txt
for c in kube-controller-manager kube-scheduler; do
  m=/etc/kubernetes/manifests/$c.yaml
  grep -q -- '--profiling=false' $m || sed -i "s#^\(\s*\)- $c\$#&\n\1- --profiling=false#" $m
done
sleep 20
for c in kube-controller-manager kube-scheduler; do
  kubectl -n kube-system wait --for=condition=Ready pod/$c-controlplane --timeout=180s
done
