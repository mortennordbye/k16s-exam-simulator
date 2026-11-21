#!/usr/bin/env bash
D=/opt/candidate-binaries
K=/var/lib/k16s/tasks/b13-sha512.txt

if [[ -e "$D/kubelet" ]]; then
  echo "FAIL: $D/kubelet does not match its checksum and must be deleted"
  exit 1
fi

if [[ -e "$D/kube-apiserver" ]]; then
  echo "FAIL: $D/kube-apiserver does not match its checksum and must be deleted"
  exit 1
fi

if ! (cd "$D" 2>/dev/null && grep -E ' (kubectl|kubeadm|kube-proxy)$' "$K" | sha512sum -c --quiet - >/dev/null 2>&1) || [[ ! -f "$D/SHA512SUMS.txt" ]]; then
  echo "FAIL: kubectl, kubeadm and kube-proxy match their checksums and must stay, together with SHA512SUMS.txt"
  exit 1
fi

echo "PASS: only the binaries with a wrong checksum were deleted"
