#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
P=$(kubectl -n orders get pod app -o json 2>/dev/null)
[[ -n "$P" ]] || P='{}'
py() { python3 -c "import sys,json; p=json.loads(sys.argv[1]); $1" "$P" >/dev/null 2>&1; }

if ! py "assert p['status']['phase']=='Running' and p['spec']['containers'][0]['image']=='busybox:1.37' and not p['metadata'].get('deletionTimestamp')"; then
  echo "FAIL: pod app in namespace orders is not Running with image busybox:1.37"
  exit 1
fi

if ! py "
c=p['spec']['containers']
assert c
for x in c:
    assert not any((e.get('valueFrom') or {}).get('secretKeyRef') for e in x.get('env',[]))
    assert not any(f.get('secretRef') for f in x.get('envFrom',[]))"; then
  echo "FAIL: pod app still gets secret values through environment variables"
  exit 1
fi

if ! py "
s=p['spec']
vols=[v['name'] for v in s.get('volumes',[]) if (v.get('secret') or {}).get('secretName')=='db-secret']
m=[x for x in s['containers'][0].get('volumeMounts',[]) if x['name'] in vols and x['mountPath'].rstrip('/')=='/etc/db-secret']
assert m and m[0].get('readOnly') is True"; then
  echo "FAIL: secret db-secret is not mounted read-only at /etc/db-secret in pod app"
  exit 1
fi

if [[ "$(kubectl -n orders exec app -- cat /etc/db-secret/password 2>/dev/null)" != "0rd3rsPa55" ]]; then
  echo "FAIL: /etc/db-secret/password in pod app does not hold the db-secret password"
  exit 1
fi

if [[ "$(tr -d '[:space:]' < /opt/cks-secrets/legacy-token.txt 2>/dev/null)" != "lt-29f8c1d04e" ]]; then
  echo "FAIL: /opt/cks-secrets/legacy-token.txt does not hold the decoded token of secret legacy-token"
  exit 1
fi

echo "PASS: db-secret is mounted read-only in pod app and the legacy token is decoded"
