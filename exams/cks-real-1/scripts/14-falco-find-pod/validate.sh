#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
rep() { kubectl -n "$1" get deployment "$2" -o jsonpath='{.spec.replicas}/{.status.readyReplicas}' 2>/dev/null; }

R=$(kubectl -n finance get deployment reporter -o jsonpath='{.spec.replicas}' 2>/dev/null)
N=$(kubectl -n finance get pods -l app=reporter --no-headers 2>/dev/null | wc -l)
if [[ "$R" != "0" || "$N" != "0" ]]; then
  echo "FAIL: the deployment of the pod that reads /etc/shadow is not scaled to 0, or its pods still exist"
  exit 1
fi

if [[ "$(rep frontend web-cache)" != "1/1" || "$(rep metrics collector)" != "1/1" ]]; then
  echo "FAIL: other deployments (frontend/web-cache, metrics/collector) were changed and must still run 1 replica"
  exit 1
fi

if ! grep -qxE 'finance/reporter-[a-z0-9]+-[a-z0-9]{5}' <(tr -d '[:space:]' < /opt/cks-falco/suspicious-pod.txt 2>/dev/null; echo); then
  echo "FAIL: /opt/cks-falco/suspicious-pod.txt does not hold <namespace>/<pod-name> of the pod that reads /etc/shadow"
  exit 1
fi

echo "PASS: the pod that reads /etc/shadow was found with Falco and its deployment is scaled to 0"
