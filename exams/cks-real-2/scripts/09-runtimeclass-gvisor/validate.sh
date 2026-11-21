#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
NS=sandbox

if [[ "$(kubectl get runtimeclass gvisor -o jsonpath='{.handler}' 2>/dev/null)" != "runsc" ]]; then
  echo "FAIL: RuntimeClass gvisor with handler runsc not found"
  exit 1
fi

if [[ "$(kubectl -n $NS get deployment payments -o jsonpath='{.spec.template.spec.runtimeClassName}' 2>/dev/null)" != "gvisor" ]]; then
  echo "FAIL: deployment payments does not use runtimeClassName gvisor"
  exit 1
fi

PODS=$(kubectl -n $NS get pods -l app=payments -o json 2>/dev/null | python3 -c '
import sys, json
items = json.load(sys.stdin)["items"]
ok = [p["metadata"]["name"] for p in items
      if p["spec"].get("runtimeClassName") == "gvisor" and p["status"].get("phase") == "Running"
      and not p["metadata"].get("deletionTimestamp")
      and all(c.get("ready") for c in p["status"].get("containerStatuses", []))]
bad = [p for p in items if p["spec"].get("runtimeClassName") != "gvisor"]
if len(ok) >= 2 and not bad:
    print(ok[0])' 2>/dev/null)
if [[ -z "$PODS" ]]; then
  echo "FAIL: the payments pods are not all Running and ready with RuntimeClass gvisor"
  exit 1
fi

if [[ -z "$PODS" ]] || ! kubectl -n $NS exec "$PODS" -- dmesg 2>/dev/null | grep -q gVisor; then
  echo "FAIL: dmesg in a payments pod does not show gVisor: the pod does not run in the sandbox"
  exit 1
fi

if ! grep -q gVisor /opt/cks-gvisor/dmesg.txt 2>/dev/null || [[ -n "$(kubectl -n $NS get deployment ledger -o jsonpath='{.spec.template.spec.runtimeClassName}' 2>/dev/null)" ]]; then
  echo "FAIL: /opt/cks-gvisor/dmesg.txt does not hold the gVisor dmesg output, or deployment ledger was changed"
  exit 1
fi

echo "PASS: payments runs in gVisor through RuntimeClass gvisor"
