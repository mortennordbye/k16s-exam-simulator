#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
NS=secure-apps
lbl() { kubectl get ns $NS -o jsonpath="{.metadata.labels.pod-security\.kubernetes\.io/$1}" 2>/dev/null; }

if [[ "$(lbl enforce)" != "restricted" ]]; then
  echo "FAIL: namespace secure-apps does not have label pod-security.kubernetes.io/enforce=restricted"
  exit 1
fi

if [[ "$(lbl warn)" != "restricted" ]]; then
  echo "FAIL: namespace secure-apps does not have label pod-security.kubernetes.io/warn=restricted"
  exit 1
fi

D=$(kubectl -n $NS get deployment web -o json 2>/dev/null)
[[ -n "$D" ]] || D='{}'
if ! python3 -c '
import sys, json
d = json.loads(sys.argv[1]); s = d.get("status", {})
assert d["spec"]["template"]["spec"]["containers"][0]["image"] == "nginxinc/nginx-unprivileged:1.27-alpine"
assert s.get("readyReplicas") == 2 and s.get("updatedReplicas") == 2 and s.get("replicas") == 2
' "$D" 2>/dev/null; then
  echo "FAIL: deployment web does not have 2 ready, up-to-date replicas with the original image"
  exit 1
fi

if ! python3 -c '
import sys, json
t = json.loads(sys.argv[1])["spec"]["template"]["spec"]
psc = t.get("securityContext") or {}
for c in t["containers"]:
    sc = c.get("securityContext") or {}
    assert sc.get("runAsNonRoot", psc.get("runAsNonRoot")) is True
    assert sc.get("allowPrivilegeEscalation") is False
    assert "ALL" in ((sc.get("capabilities") or {}).get("drop") or [])
    sp = (sc.get("seccompProfile") or psc.get("seccompProfile") or {}).get("type")
    assert sp in ("RuntimeDefault", "Localhost")
' "$D" 2>/dev/null; then
  echo "FAIL: the pod template of web is missing runAsNonRoot, allowPrivilegeEscalation false, drop ALL or seccomp RuntimeDefault"
  exit 1
fi

P=$(kubectl -n $NS get pods -o json 2>/dev/null)
[[ -n "$P" ]] || P='{"items":[{}]}'
if ! python3 -c '
import sys, json
for p in json.loads(sys.argv[1])["items"]:
    if p["metadata"].get("deletionTimestamp"):
        continue
    s = p["spec"]; psc = s.get("securityContext") or {}
    for c in s.get("containers", []) + s.get("initContainers", []):
        sc = c.get("securityContext") or {}
        assert sc.get("runAsNonRoot", psc.get("runAsNonRoot")) is True
        assert sc.get("allowPrivilegeEscalation") is False
        assert "ALL" in ((sc.get("capabilities") or {}).get("drop") or [])
        assert (sc.get("seccompProfile") or psc.get("seccompProfile") or {}).get("type") in ("RuntimeDefault", "Localhost")
        assert not sc.get("privileged")
' "$P" 2>/dev/null; then
  echo "FAIL: pods that break the restricted standard still exist in namespace secure-apps"
  exit 1
fi

echo "PASS: secure-apps enforces restricted and deployment web runs compliant pods"
