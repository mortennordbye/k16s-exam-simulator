#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
exists() { kubectl -n scan get pod "$1" >/dev/null 2>&1; }

if exists web; then
  echo "FAIL: pod web (image with CRITICAL vulnerabilities) still exists"
  exit 1
fi

if exists cache; then
  echo "FAIL: pod cache (image with CRITICAL vulnerabilities) still exists"
  exit 1
fi

if exists proxy; then
  echo "FAIL: pod proxy (image with CRITICAL vulnerabilities) still exists"
  exit 1
fi

if ! exists api || ! exists tools; then
  echo "FAIL: pods api and tools have no CRITICAL vulnerabilities and must not be deleted"
  exit 1
fi

echo "PASS: pods with CRITICAL image vulnerabilities are deleted, clean pods are kept"
