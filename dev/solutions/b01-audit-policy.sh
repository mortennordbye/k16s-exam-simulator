#!/usr/bin/env bash
# Reference solution for b01-audit-policy (run as root on controlplane)
export KUBECONFIG=/etc/kubernetes/admin.conf

wait_api() { local old="$1"; for i in $(seq 1 120); do new=$(pgrep -xo kube-apiserver); [[ -n "$new" && "$new" != "$old" ]] && kubectl get --raw=/readyz >/dev/null 2>&1 && return 0; sleep 1; done; echo "apiserver not back"; }

cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: Metadata
  namespaces: ["prod-secure"]
  resources:
  - group: ""
    resources: ["secrets"]
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["pods"]
- level: Request
  namespaces: ["prod-secure"]
  resources:
  - group: "apps"
    resources: ["deployments"]
- level: None
EOF
OLD=$(pgrep -xo kube-apiserver)
python3 - <<'PY'
import yaml
M = "/etc/kubernetes/manifests/kube-apiserver.yaml"
d = yaml.safe_load(open(M)); c = d["spec"]["containers"][0]
c["command"] = [x for x in c["command"] if not x.startswith("--audit-")] + [
  "--audit-policy-file=/etc/kubernetes/audit/policy.yaml",
  "--audit-log-path=/var/log/kubernetes/audit/audit.log",
  "--audit-log-maxbackup=2", "--audit-log-maxage=10"]
c["volumeMounts"] += [{"name": "audit-policy", "mountPath": "/etc/kubernetes/audit", "readOnly": True},
                      {"name": "audit-log", "mountPath": "/var/log/kubernetes/audit"}]
d["spec"]["volumes"] += [{"name": "audit-policy", "hostPath": {"path": "/etc/kubernetes/audit", "type": "DirectoryOrCreate"}},
                         {"name": "audit-log", "hostPath": {"path": "/var/log/kubernetes/audit", "type": "DirectoryOrCreate"}}]
open(M, "w").write(yaml.safe_dump(d, sort_keys=False))
PY
wait_api "$OLD"
