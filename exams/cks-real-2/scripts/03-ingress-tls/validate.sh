#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
I=$(kubectl -n shop get ingress shop-ingress -o json 2>/dev/null)
[[ -n "$I" ]] || I='{}'
py() { python3 -c "import sys,json; i=json.loads(sys.argv[1]); $1" "$I" >/dev/null 2>&1; }

if [[ "$(kubectl -n shop get secret shop-tls -o jsonpath='{.type}' 2>/dev/null)" != "kubernetes.io/tls" ]]; then
  echo "FAIL: secret shop-tls of type kubernetes.io/tls not found in namespace shop"
  exit 1
fi

WANT=$(openssl x509 -in /opt/cks-ingress/shop.crt -noout -fingerprint -sha256 2>/dev/null)
GOT=$(kubectl -n shop get secret shop-tls -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null)
if [[ -z "$WANT" || "$WANT" != "$GOT" ]]; then
  echo "FAIL: secret shop-tls does not hold the certificate /opt/cks-ingress/shop.crt"
  exit 1
fi

if ! py "
r=[x for x in i['spec']['rules'] if x.get('host')=='shop.k16s.local'][0]
p=[x for x in r['http']['paths'] if x['path']=='/'][0]
assert p['pathType']=='Prefix'
assert p['backend']['service']['name']=='shop-svc' and p['backend']['service']['port'].get('number')==80"; then
  echo "FAIL: Ingress shop-ingress must route host shop.k16s.local path / (Prefix) to shop-svc port 80"
  exit 1
fi

if ! py "assert any('shop.k16s.local' in t.get('hosts',[]) and t.get('secretName')=='shop-tls' for t in i['spec']['tls'])"; then
  echo "FAIL: Ingress shop-ingress has no TLS entry for host shop.k16s.local with secret shop-tls"
  exit 1
fi

if ! py "assert i['spec'].get('ingressClassName')=='nginx'"; then
  echo "FAIL: Ingress shop-ingress must use ingress class nginx"
  exit 1
fi

echo "PASS: Ingress shop-ingress serves shop.k16s.local with TLS secret shop-tls"
