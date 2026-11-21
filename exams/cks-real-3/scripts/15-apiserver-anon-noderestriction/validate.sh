#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf

APISERVER_ARGS=$(ps -eo args | grep -E '^kube-apiserver ' | head -1 | tr ' ' '\n')
api_arg() { echo "$APISERVER_ARGS" | grep -E "^--$1=" | tail -1 | cut -d= -f2-; }

READY=no
kubectl get --raw=/readyz >/dev/null 2>&1 && READY=yes
IP=$(api_arg advertise-address); IP=${IP:-127.0.0.1}
anon() { curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "https://$IP:6443$1" 2>/dev/null; }

if [[ "$READY" != "yes" ]]; then
  echo "FAIL: kube-apiserver is not running or kubectl cannot reach it"
  exit 1
fi

if [[ "$(api_arg authentication-config)" != "/etc/kubernetes/authn/authn-config.yaml" ]]; then
  echo "FAIL: kube-apiserver does not run with --authentication-config=/etc/kubernetes/authn/authn-config.yaml"
  exit 1
fi

CODE=$(anon /version)
if [[ "$CODE" != "401" ]] || [[ "$(anon /api/v1/namespaces)" != "401" ]]; then
  echo "FAIL: anonymous requests to /version and /api are not rejected with 401 (got $CODE)"
  exit 1
fi

if [[ "$(anon /livez)" != "200" || "$(anon /readyz)" != "200" || "$(anon /healthz)" != "200" ]]; then
  echo "FAIL: anonymous requests to /livez, /readyz and /healthz must still work, or the kubelet probes fail"
  exit 1
fi

if ! api_arg enable-admission-plugins | tr ',' '\n' | grep -qx NodeRestriction; then
  echo "FAIL: NodeRestriction is not in --enable-admission-plugins"
  exit 1
fi

OUT=$(kubectl --kubeconfig /etc/kubernetes/kubelet.conf label node controlplane node-restriction.kubernetes.io/k16s-probe=x --overwrite --dry-run=server 2>&1)
if [[ "$READY" != "yes" ]] || ! echo "$OUT" | grep -qi 'forbidden'; then
  echo "FAIL: the kubelet can still set node-restriction.kubernetes.io labels: NodeRestriction is not active"
  exit 1
fi

echo "PASS: anonymous access is limited to health endpoints and NodeRestriction is enabled"
