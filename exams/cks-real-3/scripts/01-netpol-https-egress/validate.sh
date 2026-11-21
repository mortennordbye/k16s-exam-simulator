#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

DENY=$(kubectl get networkpolicy deny-all-egress -n netpol-external -o json 2>/dev/null) || true
[[ -n "$DENY" ]] || DENY='{}'
if [[ "$(echo "$DENY" | python3 -c "
import sys, json
s = json.load(sys.stdin).get('spec')
print('ok' if s and (s.get('podSelector') or {}) == {} and 'Egress' in s.get('policyTypes', []) and not s.get('egress') else '')
" 2>/dev/null)" != "ok" ]]; then
  echo "FAIL: deny-all-egress in netpol-external must select all pods (podSelector: {}), have Egress in policyTypes and no egress rules"
  exit 1
fi

NP=$(kubectl get networkpolicy allow-external-https -n netpol-external -o json 2>/dev/null) || {
  echo "FAIL: NetworkPolicy allow-external-https not found in namespace netpol-external"
  exit 1
}

if [[ "$(echo "$NP" | python3 -c "import sys,json; print(((json.load(sys.stdin)['spec'].get('podSelector') or {}).get('matchLabels') or {}).get('app',''))" 2>/dev/null)" != "client" ]]; then
  echo "FAIL: allow-external-https must apply to pods with label app=client"
  exit 1
fi

FOUND_HTTPS=$(echo "$NP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for rule in d['spec'].get('egress', []):
    ports = [p.get('port') for p in rule.get('ports', [])]
    if 443 not in ports: continue
    for peer in rule.get('to', []):
        ib = peer.get('ipBlock', {})
        if ib.get('cidr') == '0.0.0.0/0':
            excepts = ib.get('except', [])
            if '169.254.169.254/32' in excepts and '10.10.0.0/16' in excepts:
                print('ok'); sys.exit(0)
print('missing')
")
if [[ "$FOUND_HTTPS" != "ok" ]]; then
  echo "FAIL: no egress rule for TCP 443 to 0.0.0.0/0 with except 169.254.169.254/32 and 10.10.0.0/16"
  exit 1
fi

FOUND_DNS=$(echo "$NP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
found = set()
for rule in d['spec'].get('egress', []):
    if not any(((p.get('namespaceSelector') or {}).get('matchLabels') or {}).get('kubernetes.io/metadata.name') == 'kube-system' for p in rule.get('to', [])):
        continue
    for p in rule.get('ports', []):
        if p.get('port') == 53:
            found.add(p.get('protocol', 'TCP'))
print('ok' if {'UDP', 'TCP'} <= found else 'missing')
")
if [[ "$FOUND_DNS" != "ok" ]]; then
  echo "FAIL: no egress rule for UDP and TCP port 53 to namespace kube-system (DNS)"
  exit 1
fi

if [[ ! -f /opt/cks3-netpol/allow-external-https.yaml ]]; then
  echo "FAIL: /opt/cks3-netpol/allow-external-https.yaml not saved"
  exit 1
fi

echo "PASS: deny-all-egress in place; allow-external-https permits TCP 443 (0.0.0.0/0 except metadata) and DNS UDP/TCP 53 to kube-system"
