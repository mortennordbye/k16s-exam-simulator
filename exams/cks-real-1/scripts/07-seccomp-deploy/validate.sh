#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

DEPLOY="seccomp-app"
NS="seccomp-apps"

# Check seccompProfile.type=RuntimeDefault on the pod template and a complete rollout
TYPE=$(kubectl get deployment "$DEPLOY" -n "$NS" \
  -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}' 2>/dev/null)
ROLLOUT=$(kubectl get deployment "$DEPLOY" -n "$NS" \
  -o jsonpath='{.spec.replicas}/{.status.replicas}/{.status.updatedReplicas}/{.status.readyReplicas}/{.status.unavailableReplicas}' 2>/dev/null)
NODES=$(kubectl get pods -n "$NS" -l app=seccomp-app -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)
if [[ "$TYPE" != "RuntimeDefault" ]] || [[ "$ROLLOUT" != "1/1/1/1/" ]] || [[ "$NODES" != "controlplane" ]]; then
  echo "FAIL: deployment pod template seccompProfile.type is '${TYPE:-unset}' (expected RuntimeDefault), or the rollout is not complete (spec/replicas/updated/ready/unavailable: $ROLLOUT)"
  exit 1
fi

echo "PASS: deployment seccomp-app uses RuntimeDefault seccomp; all replicas ready"
