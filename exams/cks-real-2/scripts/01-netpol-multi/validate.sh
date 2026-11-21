#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

if [[ "$(kubectl get namespace dmz -o jsonpath='{.metadata.labels.zone}' 2>/dev/null)" != "dmz" ]]; then
  echo "FAIL: namespace dmz does not have label zone=dmz"
  exit 1
fi

if [[ "$(kubectl get namespace internal -o jsonpath='{.metadata.labels.zone}' 2>/dev/null)" != "internal" ]]; then
  echo "FAIL: namespace internal does not have label zone=internal"
  exit 1
fi

NP=$(kubectl get networkpolicy restrict-ingress-egress -n netpol-multi -o json 2>/dev/null)
if [[ -z "$NP" ]]; then
  echo "FAIL: NetworkPolicy restrict-ingress-egress not found in namespace netpol-multi"
  exit 1
fi

# Ingress: port 8080 from role=client in zone=dmz
FOUND_INGRESS=$(echo "$NP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for rule in d['spec'].get('ingress', []):
    ports = [p.get('port') for p in rule.get('ports', [])]
    if 8080 not in ports: continue
    for peer in rule.get('from', []):
        ns = peer.get('namespaceSelector', {}).get('matchLabels', {})
        ps = peer.get('podSelector', {}).get('matchLabels', {})
        if ns.get('zone') == 'dmz' and ps.get('role') == 'client':
            print('ok'); sys.exit(0)
print('missing')
")
if [[ "$FOUND_INGRESS" != "ok" ]]; then
  echo "FAIL: no ingress rule for port 8080 from role=client in zone=dmz"
  exit 1
fi

# Egress: port 3306 to role=db in zone=internal
FOUND_DB=$(echo "$NP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for rule in d['spec'].get('egress', []):
    ports = [p.get('port') for p in rule.get('ports', [])]
    if 3306 not in ports: continue
    for peer in rule.get('to', []):
        ns = peer.get('namespaceSelector', {}).get('matchLabels', {})
        ps = peer.get('podSelector', {}).get('matchLabels', {})
        if ns.get('zone') == 'internal' and ps.get('role') == 'db':
            print('ok'); sys.exit(0)
print('missing')
")
if [[ "$FOUND_DB" != "ok" ]]; then
  echo "FAIL: no egress rule for port 3306 to role=db in zone=internal"
  exit 1
fi

# Egress: UDP and TCP 53 to CoreDNS in kube-system
FOUND_DNS=$(echo "$NP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
def dns_peer(p):
    ns = (p.get('namespaceSelector') or {}).get('matchLabels') or {}
    ps = (p.get('podSelector') or {}).get('matchLabels') or {}
    return ns.get('kubernetes.io/metadata.name') == 'kube-system' and ps.get('k8s-app') == 'kube-dns'
found = set()
for rule in d['spec'].get('egress', []):
    if not any(dns_peer(p) for p in rule.get('to', [])): continue
    for p in rule.get('ports', []):
        if p.get('port') == 53:
            found.add(p.get('protocol', 'TCP'))
print('ok' if {'UDP', 'TCP'} <= found else 'missing')
")
if [[ "$FOUND_DNS" != "ok" ]]; then
  echo "FAIL: no egress rule for UDP and TCP port 53 to pods k8s-app=kube-dns in namespace kube-system"
  exit 1
fi

if [[ "$(echo "$NP" | python3 -c "import sys,json; t=json.load(sys.stdin)['spec'].get('policyTypes',[]); print('ok' if 'Ingress' in t and 'Egress' in t else '')")" != "ok" ]]; then
  echo "FAIL: restrict-ingress-egress must have both Ingress and Egress in policyTypes"
  exit 1
fi

if ! grep -q 'name: *restrict-ingress-egress' /opt/cks3-netpol/restrict-ingress-egress.yaml 2>/dev/null; then
  echo "FAIL: /opt/cks3-netpol/restrict-ingress-egress.yaml not saved (it must hold the policy restrict-ingress-egress)"
  exit 1
fi

echo "PASS: zone labels set; restrict-ingress-egress policy has correct ingress (8080/dmz), egress (3306/internal), and DNS (UDP/TCP 53 to kube-system) rules"