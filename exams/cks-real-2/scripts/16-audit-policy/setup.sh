#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

# Remove kube-apiserver flags (by prefix) and hostPath volumes (by path prefix)
# left over from an earlier attempt. Prints "changed" when the manifest changed.
strip_apiserver() {
  python3 - "$@" <<'PY'
import sys, yaml
M = "/etc/kubernetes/manifests/kube-apiserver.yaml"
flags = [a for a in sys.argv[1:] if a.startswith("--")]
paths = [a for a in sys.argv[1:] if a.startswith("/")]
d = yaml.safe_load(open(M))
c = d["spec"]["containers"][0]
before = yaml.safe_dump(d)
c["command"] = [x for x in c["command"] if not any(x.startswith(f) for f in flags)]
vols = d["spec"].get("volumes", [])
drop = {v["name"] for v in vols if any(v.get("hostPath", {}).get("path", "").startswith(p) for p in paths)}
d["spec"]["volumes"] = [v for v in vols if v["name"] not in drop]
c["volumeMounts"] = [m for m in c.get("volumeMounts", []) if m["name"] not in drop]
if yaml.safe_dump(d) != before:
    open(M, "w").write(yaml.safe_dump(d, default_flow_style=False, sort_keys=False))
    print("changed")
PY
}

# Wait until kubelet has started a new kube-apiserver process and it is ready.
wait_apiserver_restart() {
  local old="$1" new
  for _ in $(seq 1 100); do
    new=$(pgrep -xo kube-apiserver || true)
    if [[ -n "$new" && "$new" != "$old" ]] && kubectl get --raw=/readyz >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "warning: kube-apiserver did not come back in time" >&2
  return 0
}

OLD=$(pgrep -xo kube-apiserver || true)
if [[ "$(strip_apiserver --audit- /etc/kubernetes/audit /var/log/kubernetes/audit)" == "changed" ]]; then
  wait_apiserver_restart "$OLD"
fi

kubectl create namespace prod-secure --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
rm -f /var/log/kubernetes/audit/audit*.log
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Add your rules here.
- level: Metadata
EOF
echo "Environment ready: starter policy at /etc/kubernetes/audit/policy.yaml"
