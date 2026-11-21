#!/usr/bin/env bash
# Reference solution for b02-encryption-at-rest
export KUBECONFIG=/etc/kubernetes/admin.conf

wait_api() { local old="$1"; for i in $(seq 1 120); do new=$(pgrep -xo kube-apiserver); [[ -n "$new" && "$new" != "$old" ]] && kubectl get --raw=/readyz >/dev/null 2>&1 && return 0; sleep 1; done; echo "apiserver not back"; }

mkdir -p /etc/kubernetes/enc
KEY=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/encryption.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources: ["secrets"]
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: $KEY
  - identity: {}
EOF
OLD=$(pgrep -xo kube-apiserver)
python3 - <<'PY'
import yaml
M = "/etc/kubernetes/manifests/kube-apiserver.yaml"
d = yaml.safe_load(open(M)); c = d["spec"]["containers"][0]
c["command"] = [x for x in c["command"] if not x.startswith("--encryption-provider-config")] + ["--encryption-provider-config=/etc/kubernetes/enc/encryption.yaml"]
c["volumeMounts"].append({"name": "enc", "mountPath": "/etc/kubernetes/enc", "readOnly": True})
d["spec"]["volumes"].append({"name": "enc", "hostPath": {"path": "/etc/kubernetes/enc", "type": "DirectoryOrCreate"}})
open(M, "w").write(yaml.safe_dump(d, sort_keys=False))
PY
wait_api "$OLD"
kubectl -n team-green get secrets -o json | kubectl replace -f -
