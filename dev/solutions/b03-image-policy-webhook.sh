#!/usr/bin/env bash
# Reference solution for b03-image-policy-webhook
export KUBECONFIG=/etc/kubernetes/admin.conf

wait_api() { local old="$1"; for i in $(seq 1 120); do new=$(pgrep -xo kube-apiserver); [[ -n "$new" && "$new" != "$old" ]] && kubectl get --raw=/readyz >/dev/null 2>&1 && return 0; sleep 1; done; echo "apiserver not back"; }

P=/etc/kubernetes/policywebhook
sed -i 's/defaultAllow: true/defaultAllow: false/' $P/admission_config.yaml
sed -i 's#server: https://CHANGE-ME#server: https://image-bouncer.k16s.local:8443/review#' $P/kubeconf
OLD=$(pgrep -xo kube-apiserver)
python3 - <<'PY'
import yaml
M = "/etc/kubernetes/manifests/kube-apiserver.yaml"
d = yaml.safe_load(open(M)); c = d["spec"]["containers"][0]
cmd = []
for x in c["command"]:
    if x.startswith("--enable-admission-plugins="):
        x = x + ",ImagePolicyWebhook"
    cmd.append(x)
cmd.append("--admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.yaml")
c["command"] = cmd
c["volumeMounts"].append({"name": "policywebhook", "mountPath": "/etc/kubernetes/policywebhook", "readOnly": True})
d["spec"]["volumes"].append({"name": "policywebhook", "hostPath": {"path": "/etc/kubernetes/policywebhook", "type": "DirectoryOrCreate"}})
open(M, "w").write(yaml.safe_dump(d, sort_keys=False))
PY
wait_api "$OLD"
