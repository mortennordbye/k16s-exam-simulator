#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf

APISERVER_ARGS=$(ps -eo args | grep -E '^kube-apiserver ' | head -1 | tr ' ' '\n')
api_arg() { echo "$APISERVER_ARGS" | grep -E "^--$1=" | tail -1 | cut -d= -f2-; }

LOG=/var/log/kubernetes/audit/audit.log
TAG="probe$RANDOM$RANDOM"
READY=no
kubectl get --raw=/readyz >/dev/null 2>&1 && READY=yes

if [[ "$READY" != "yes" ]] || [[ "$(api_arg audit-policy-file)" != "/etc/kubernetes/audit/policy.yaml" ]]; then
  echo "FAIL: kube-apiserver is not ready or does not run with --audit-policy-file=/etc/kubernetes/audit/policy.yaml"
  exit 1
fi

if [[ "$(api_arg audit-log-path)" != "$LOG" || "$(api_arg audit-log-maxbackup)" != "2" || "$(api_arg audit-log-maxage)" != "10" ]]; then
  echo "FAIL: kube-apiserver must run with --audit-log-path=$LOG --audit-log-maxbackup=2 --audit-log-maxage=10"
  exit 1
fi

# Send probe requests, then read what the audit log recorded for them.
START=$(date -u +%Y-%m-%dT%H:%M:%S.%6NZ)
if [[ "$READY" == "yes" ]]; then
  kubectl -n prod-secure create secret generic "s-$TAG" --from-literal=k=v >/dev/null 2>&1
  kubectl -n prod-secure delete secret "s-$TAG" >/dev/null 2>&1
  kubectl -n default run "p-$TAG" --image=nginx:1.27-alpine --dry-run=server -o name >/dev/null 2>&1
  kubectl -n prod-secure create deployment "d-$TAG" --image=nginx:1.27-alpine --dry-run=server -o name >/dev/null 2>&1
  kubectl -n prod-secure create configmap "c-$TAG" --from-literal=k=v --dry-run=server -o name >/dev/null 2>&1
  sleep 3
fi
EVENTS=$(python3 - "$LOG" "$START" <<'PY' 2>/dev/null
import sys, json
log, start = sys.argv[1], sys.argv[2]
out = {}
try:
    lines = open(log).read().splitlines()[-20000:]
except Exception:
    lines = []
for l in lines:
    try:
        e = json.loads(l)
    except Exception:
        continue
    if e.get("requestReceivedTimestamp", "") < start:
        continue
    if (e.get("user") or {}).get("username") != "kubernetes-admin":
        continue
    ref = e.get("objectRef") or {}
    key = ref.get("namespace", "") + "/" + ref.get("resource", "")
    out.setdefault(key, []).append([e.get("level"), e.get("stage"), e.get("verb")])
print(json.dumps(out))
PY
)
[[ -n "$EVENTS" ]] || EVENTS='{}'
ev() { python3 -c "import sys,json; d=json.loads(sys.argv[1]); $1" "$EVENTS" >/dev/null 2>&1; }

if ! ev "e=d.get('prod-secure/secrets',[]); assert e and all(x[0]=='Metadata' for x in e) and any(x[2]=='create' for x in e)"; then
  echo "FAIL: a secret created in namespace prod-secure was not logged at level Metadata"
  exit 1
fi

if ! ev "e=d.get('default/pods',[]); assert e and all(x[0]=='RequestResponse' for x in e)"; then
  echo "FAIL: a pod create request was not logged at level RequestResponse"
  exit 1
fi

if ! ev "e=d.get('prod-secure/deployments',[]); assert e and all(x[0]=='Request' for x in e)"; then
  echo "FAIL: a deployment created in namespace prod-secure was not logged at level Request"
  exit 1
fi

if ! ev "assert d and not d.get('prod-secure/configmaps') and not any(x[1]=='RequestReceived' for v in d.values() for x in v)"; then
  echo "FAIL: other requests (a configmap create) must not be logged, and no event may be in stage RequestReceived"
  exit 1
fi

echo "PASS: audit logging is enabled with the required policy rules and log rotation"
