#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

NS="netpol-ssh"
POLICY="allow-ssh-office"

if ! kubectl get networkpolicy "$POLICY" -n "$NS" &>/dev/null; then
  echo "FAIL: NetworkPolicy $POLICY not found in namespace $NS"
  exit 1
fi

RESULT=$(kubectl get networkpolicy "$POLICY" -n "$NS" -o json)

if ! python3 -c "
import sys,json
d=json.load(sys.stdin)
spec=d['spec']
ingress=spec.get('ingress',[])
assert (spec.get('podSelector') or {}) == {}, 'must apply to all pods'
ok=False
for r in ingress:
  peers=[p.get('ipBlock',{}) for p in r.get('from',[])]
  ports=[p.get('port') for p in r.get('ports',[])]
  if 22 in ports and any(b.get('cidr')=='203.0.113.0/24' and '203.0.113.128/25' in b.get('except',[]) for b in peers):
    ok=True
assert ok
print('ok')
" <<< "$RESULT" 2>/dev/null | grep -q ok; then
  echo "FAIL: allow-ssh-office must select all pods and have one ingress rule with port 22 from 203.0.113.0/24 except 203.0.113.128/25"
  exit 1
fi

if [[ ! -f /opt/cks-netpol/allow-ssh-office.yaml ]]; then
  echo "FAIL: manifest not saved to /opt/cks-netpol/allow-ssh-office.yaml"
  exit 1
fi

echo "PASS: allow-ssh-office permits TCP 22 from 203.0.113.0/24 (excluding 203.0.113.128/25)"
