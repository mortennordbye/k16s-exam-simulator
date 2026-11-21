#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf

wait_api() { local old="$1"; for i in $(seq 1 120); do new=$(pgrep -xo kube-apiserver); [[ -n "$new" && "$new" != "$old" ]] && kubectl get --raw=/readyz >/dev/null 2>&1 && return 0; sleep 1; done; echo "apiserver not back"; }

mkdir -p /etc/kubernetes/authn
cat > /etc/kubernetes/authn/authn-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
OLD=$(pgrep -xo kube-apiserver)
python3 - <<'PY'
import yaml
M = "/etc/kubernetes/manifests/kube-apiserver.yaml"
d = yaml.safe_load(open(M)); c = d["spec"]["containers"][0]
cmd = []
for x in c["command"]:
    if x.startswith("--anonymous-auth") or x.startswith("--authentication-config"):
        continue
    if x.startswith("--enable-admission-plugins=") and "NodeRestriction" not in x:
        x += ",NodeRestriction"
    cmd.append(x)
cmd.append("--authentication-config=/etc/kubernetes/authn/authn-config.yaml")
c["command"] = cmd
c["volumeMounts"].append({"name": "authn", "mountPath": "/etc/kubernetes/authn", "readOnly": True})
d["spec"]["volumes"].append({"name": "authn", "hostPath": {"path": "/etc/kubernetes/authn", "type": "DirectoryOrCreate"}})
open(M, "w").write(yaml.safe_dump(d, sort_keys=False))
PY
wait_api "$OLD"
