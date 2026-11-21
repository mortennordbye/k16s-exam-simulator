#!/usr/bin/env bash
# Reference solution for b04-trivy-critical
export KUBECONFIG=/etc/kubernetes/admin.conf
export TRIVY_CACHE_DIR=/var/lib/trivy
for p in $(kubectl -n scan get pods -o name); do
  img=$(kubectl -n scan get "$p" -o jsonpath='{.spec.containers[0].image}')
  n=$(trivy image -q --severity CRITICAL --format json "$img" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(sum(len(r.get("Vulnerabilities") or []) for r in d.get("Results",[])))')
  echo "$p $img critical=$n"
  [ "$n" -gt 0 ] && kubectl -n scan delete "$p" --now
done
