#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
NAME=k16s-deny-tmp

if ! aa-status --json 2>/dev/null | python3 -c "import sys,json; assert '$NAME' in json.load(sys.stdin).get('profiles',{})" 2>/dev/null; then
  echo "FAIL: the AppArmor profile from /opt/cks2-apparmor/profile is not loaded"
  exit 1
fi

POD=$(kubectl get pod hosts-check -n apparmor-hosts -o json 2>/dev/null) || true
[[ -n "$POD" ]] || POD='{}'
if [[ "$(echo "$POD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',{}).get('phase','')+'/'+d.get('spec',{}).get('nodeName',''))" 2>/dev/null)" != "Running/controlplane" ]]; then
  echo "FAIL: pod hosts-check in namespace apparmor-hosts is not Running on controlplane"
  exit 1
fi

AA=$(echo "$POD" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for c in d['spec'].get('containers',[]):
    if c.get('name')!='app': continue
    ap=(c.get('securityContext') or {}).get('appArmorProfile') or (d['spec'].get('securityContext') or {}).get('appArmorProfile') or {}
    if ap.get('type')=='Localhost' and ap.get('localhostProfile')=='$NAME': print('ok')
    elif d['metadata'].get('annotations',{}).get('container.apparmor.security.beta.kubernetes.io/app')=='localhost/$NAME': print('ok')
" 2>/dev/null)
if [[ "$AA" != "ok" ]] || kubectl -n apparmor-hosts exec hosts-check -c app -- touch /tmp/k16s-probe >/dev/null 2>&1; then
  echo "FAIL: container app of pod hosts-check does not run with the AppArmor profile from /opt/cks2-apparmor/profile (writes to /tmp still work)"
  exit 1
fi

echo "PASS: profile $NAME is loaded and enforced on container app of pod hosts-check"
