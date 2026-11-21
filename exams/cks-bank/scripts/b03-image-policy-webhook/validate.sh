#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf

APISERVER_ARGS=$(ps -eo args | grep -E '^kube-apiserver ' | head -1 | tr ' ' '\n')
api_arg() { echo "$APISERVER_ARGS" | grep -E "^--$1=" | tail -1 | cut -d= -f2-; }

ACF=/etc/kubernetes/policywebhook/admission_config.yaml
READY=no
kubectl get --raw=/readyz >/dev/null 2>&1 && READY=yes

if [[ "$READY" != "yes" ]] || ! api_arg enable-admission-plugins | tr ',' '\n' | grep -qx ImagePolicyWebhook; then
  echo "FAIL: kube-apiserver is not ready or ImagePolicyWebhook is not in --enable-admission-plugins"
  exit 1
fi

if [[ "$(api_arg admission-control-config-file)" != "$ACF" ]] || ! api_arg enable-admission-plugins | tr ',' '\n' | grep -qx NodeRestriction; then
  echo "FAIL: kube-apiserver must use --admission-control-config-file=$ACF and keep NodeRestriction enabled"
  exit 1
fi

KUBECONF=$(python3 - "$ACF" <<'PY' 2>/dev/null
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
p = [x for x in d["plugins"] if x["name"] == "ImagePolicyWebhook"][0]
c = p.get("configuration") or yaml.safe_load(open(p["path"]))
ip = c.get("imagePolicy", c)
if ip.get("defaultAllow") is False:
    print(ip["kubeConfigFile"])
PY
)
if [[ -z "$KUBECONF" ]]; then
  echo "FAIL: the ImagePolicyWebhook configuration must set defaultAllow to false"
  exit 1
fi

if ! python3 - "$KUBECONF" <<'PY' >/dev/null 2>&1
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert d["clusters"][0]["cluster"]["server"].rstrip("/") == "https://image-bouncer.k16s.local:8443/review"
PY
then
  echo "FAIL: the webhook kubeconfig must use server https://image-bouncer.k16s.local:8443/review"
  exit 1
fi

OUT=$(kubectl -n team-red run "ipw-$RANDOM" --image=nginx:latest --dry-run=server -o name 2>&1)
if [[ "$READY" != "yes" ]] || ! echo "$OUT" | grep -qi "image policy webhook"; then
  echo "FAIL: a pod with image nginx:latest in namespace team-red is not rejected by the image policy webhook"
  exit 1
fi

if [[ "$READY" != "yes" ]] || ! kubectl -n team-red run "ipw-$RANDOM" --image=nginx:1.27-alpine --dry-run=server -o name >/dev/null 2>&1; then
  echo "FAIL: a pod with image nginx:1.27-alpine is rejected too: the kube-apiserver cannot reach the backend"
  exit 1
fi

echo "PASS: ImagePolicyWebhook is enabled, denies by default and uses the image review backend"
