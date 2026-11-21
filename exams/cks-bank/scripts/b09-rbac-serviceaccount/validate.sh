#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
SA=system:serviceaccount:ci:deployer
can() { [[ "$(kubectl auth can-i "$@" --as=$SA 2>/dev/null)" == "yes" ]]; }

if kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{range .subjects[*]}{.kind}/{.namespace}/{.name}{"\n"}{end}{end}' 2>/dev/null | grep -qx 'ServiceAccount/ci/deployer' || can '*' '*' -A; then
  echo "FAIL: ServiceAccount ci/deployer is still a subject of a ClusterRoleBinding or still has cluster-admin access"
  exit 1
fi

if [[ "$(kubectl -n ci get rolebinding deployer-rb -o jsonpath='{.roleRef.kind}/{.roleRef.name}/{.subjects[0].kind}/{.subjects[0].name}/{.subjects[0].namespace}' 2>/dev/null)" != "Role/deployer-role/ServiceAccount/deployer/ci" ]]; then
  echo "FAIL: RoleBinding deployer-rb in namespace ci must bind Role deployer-role to ServiceAccount deployer"
  exit 1
fi

if ! { can create deployments.apps -n ci && can patch deployments.apps -n ci && can watch deployments.apps -n ci && ! can delete deployments.apps -n ci; }; then
  echo "FAIL: deployer must get, list, watch, create, update and patch deployments in ci, but not delete them"
  exit 1
fi

if ! { can list pods -n ci && ! can create pods -n ci && ! can get secrets -n ci && ! can list deployments.apps -n default; }; then
  echo "FAIL: deployer must only get and list pods in ci, with no access to secrets or other namespaces"
  exit 1
fi

TPL=$(kubectl -n ci get deployment ci-runner -o jsonpath='{.spec.template.spec.automountServiceAccountToken}' 2>/dev/null)
SAAM=$(kubectl -n ci get sa deployer -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
RUNNING=$(kubectl -n ci get pods -l app=ci-runner -o json 2>/dev/null | python3 -c '
import sys, json
items = [p for p in json.load(sys.stdin)["items"] if not p["metadata"].get("deletionTimestamp")]
ok = items and all(p["status"].get("phase") == "Running" and
     not any(v.get("projected") and any("serviceAccountToken" in s for s in v["projected"].get("sources", []))
             for v in p["spec"].get("volumes", [])) for p in items)
print("ok" if ok else "")' 2>/dev/null)
if [[ "$RUNNING" != "ok" ]] || [[ "$TPL" != "false" && ! ( -z "$TPL" && "$SAAM" == "false" ) ]]; then
  echo "FAIL: ci-runner pods must not mount a ServiceAccount token (automountServiceAccountToken false on the pod template or the ServiceAccount)"
  exit 1
fi

echo "PASS: deployer has only the namespaced permissions it needs and ci-runner pods have no token"
