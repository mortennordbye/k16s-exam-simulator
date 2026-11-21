#!/usr/bin/env bash
set -eo pipefail
D=/opt/candidate-binaries
K=/var/lib/k16s/tasks
rm -rf "$D"; mkdir -p "$D" "$K"
cp /usr/bin/kubectl "$D/kubectl"
cp /usr/bin/kubelet "$D/kubelet"
cp /usr/bin/kubeadm "$D/kubeadm"
# Stand-ins for binaries that are not on this host (same size class, fixed content).
for b in kube-apiserver kube-proxy; do
  head -c 8388608 < <(yes "k16s-$b-stand-in") > "$D/$b"
done
chmod 755 "$D"/*
(cd "$D" && sha512sum kubectl kubelet kubeadm kube-apiserver kube-proxy > SHA512SUMS.txt)
# Tamper two files after the checksums were taken.
printf '\x00k16s' >> "$D/kubelet"
printf '\x00k16s' >> "$D/kube-apiserver"
cp "$D/SHA512SUMS.txt" "$K/b13-sha512.txt"
chmod 600 "$K/b13-sha512.txt"
echo "Environment ready: binaries and SHA512SUMS.txt in $D"
