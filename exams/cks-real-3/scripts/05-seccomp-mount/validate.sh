#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

# Check profile file exists and blocks mount
if [[ ! -f /var/lib/kubelet/seccomp/profiles/block-mount.json ]]; then
  echo "FAIL: /var/lib/kubelet/seccomp/profiles/block-mount.json not found"
  exit 1
fi
BLOCKS_MOUNT=$(python3 -c "
import json
d=json.load(open('/var/lib/kubelet/seccomp/profiles/block-mount.json'))
for s in d.get('syscalls',[]):
    if s.get('action')=='SCMP_ACT_ERRNO':
        names=s.get('names',[])
        if 'mount' in names and 'umount2' in names:
            print('ok'); exit(0)
print('missing')
")
if [[ "$BLOCKS_MOUNT" != "ok" ]]; then
  echo "FAIL: block-mount.json does not block mount and umount2 with SCMP_ACT_ERRNO"
  exit 1
fi

# Check deployment uses the profile
DEPLOY=$(kubectl get deployment mount-block -n seccomp-mount -o json 2>/dev/null) || {
  echo "FAIL: deployment mount-block not found in seccomp-mount"
  exit 1
}
SECCOMP=$(echo "$DEPLOY" | python3 -c "
import sys,json
d=json.load(sys.stdin)
sc=(d['spec']['template']['spec'].get('securityContext') or {}).get('seccompProfile') or {}
s=d.get('status',{})
n=d['spec'].get('replicas',1)
ok=sc.get('type')=='Localhost' and sc.get('localhostProfile')=='profiles/block-mount.json'
ok=ok and s.get('replicas')==n and s.get('updatedReplicas')==n and s.get('readyReplicas')==n and not s.get('unavailableReplicas')
print('ok' if ok else '')
")
if [[ "$SECCOMP" != "ok" ]]; then
  echo "FAIL: deployment mount-block does not use Localhost seccomp profiles/block-mount.json at pod level, or its rollout is not complete"
  exit 1
fi

echo "PASS: block-mount.json blocks mount+umount2; deployment mount-block uses it and is ready"
