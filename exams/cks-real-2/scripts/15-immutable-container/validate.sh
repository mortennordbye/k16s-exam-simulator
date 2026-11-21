#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
D=$(kubectl -n immutable get deployment frontend -o json 2>/dev/null)
[[ -n "$D" ]] || D='{}'
py() { python3 -c "import sys,json; d=json.loads(sys.argv[1]); t=d.get('spec',{}).get('template',{}).get('spec',{}); $1" "$D" >/dev/null 2>&1; }

if ! py "s=d['status']; assert t['containers'][0]['image']=='nginx:1.27-alpine' and s.get('readyReplicas')==2 and s.get('updatedReplicas')==2 and s.get('replicas')==2"; then
  echo "FAIL: deployment frontend does not have 2 ready, up-to-date replicas with image nginx:1.27-alpine"
  exit 1
fi

if ! py "sc=t['containers'][0].get('securityContext') or {}; assert sc.get('readOnlyRootFilesystem') is True and sc.get('allowPrivilegeEscalation') is False"; then
  echo "FAIL: container must set readOnlyRootFilesystem true and allowPrivilegeEscalation false"
  exit 1
fi

if ! py "
ed={v['name'] for v in t.get('volumes',[]) if 'emptyDir' in v}
m={x['mountPath'].rstrip('/'):x['name'] for x in t['containers'][0].get('volumeMounts',[])}
paths=['/var/cache/nginx','/var/run','/tmp']
assert all(m.get(p) in ed for p in paths) and len({m[p] for p in paths})==3"; then
  echo "FAIL: /var/cache/nginx, /var/run and /tmp must each be an own emptyDir volume"
  exit 1
fi

POD=$(kubectl -n immutable get pods -l app=frontend -o json 2>/dev/null | python3 -c '
import sys, json
for p in json.load(sys.stdin)["items"]:
    if p["status"].get("phase") == "Running" and not p["metadata"].get("deletionTimestamp"):
        print(p["metadata"]["name"]); break' 2>/dev/null)
if [[ -z "$POD" ]] || kubectl -n immutable exec "$POD" -- touch /usr/share/nginx/html/k16s-probe >/dev/null 2>&1 ||
   ! kubectl -n immutable exec "$POD" -- touch /tmp/k16s-probe >/dev/null 2>&1; then
  echo "FAIL: in a running frontend pod the root filesystem is writable or /tmp is not writable"
  exit 1
fi

echo "PASS: frontend runs with a read-only root filesystem and emptyDir volumes for its write paths"
