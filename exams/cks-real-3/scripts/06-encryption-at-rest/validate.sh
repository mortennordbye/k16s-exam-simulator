#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf

APISERVER_ARGS=$(ps -eo args | grep -E '^kube-apiserver ' | head -1 | tr ' ' '\n')
api_arg() { echo "$APISERVER_ARGS" | grep -E "^--$1=" | tail -1 | cut -d= -f2-; }

CONF=/etc/kubernetes/enc/encryption.yaml
ETCD="etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt --key=/etc/kubernetes/pki/apiserver-etcd-client.key"
READY=no
kubectl get --raw=/readyz >/dev/null 2>&1 && READY=yes
stored() { $ETCD get "/registry/secrets/$1" --print-value-only 2>/dev/null | head -c 22 | tr -d '\0'; }

if [[ "$READY" != "yes" ]] || [[ "$(api_arg encryption-provider-config)" != "$CONF" ]]; then
  echo "FAIL: kube-apiserver is not ready or does not run with --encryption-provider-config=$CONF"
  exit 1
fi

if ! python3 - "$CONF" <<'PY' >/dev/null 2>&1
import sys, yaml, base64
d = yaml.safe_load(open(sys.argv[1]))
assert d["kind"] == "EncryptionConfiguration"
r = [x for x in d["resources"] if "secrets" in x["resources"]][0]
p = r["providers"]
assert "aescbc" in p[0]
keys = p[0]["aescbc"]["keys"]
assert keys[0]["name"] == "key1"
assert len(base64.b64decode(keys[0]["secret"])) == 32
assert any("identity" in x for x in p)
PY
then
  echo "FAIL: $CONF must encrypt secrets with aescbc first (32-byte key named key1) and keep identity as a fallback"
  exit 1
fi

PROBE="enc-probe-$RANDOM"
if [[ "$READY" == "yes" ]]; then
  kubectl -n default create secret generic "$PROBE" --from-literal=k=v >/dev/null 2>&1
fi
P=$(stored "default/$PROBE")
kubectl -n default delete secret "$PROBE" --ignore-not-found >/dev/null 2>&1
if [[ "$P" != "k8s:enc:aescbc:v1:key1" ]]; then
  echo "FAIL: a new secret is not stored in etcd with prefix k8s:enc:aescbc:v1:key1"
  exit 1
fi

if [[ "$(stored team-green/db-creds)" != "k8s:enc:aescbc:v1:key1" ]]; then
  echo "FAIL: secret db-creds in namespace team-green is not stored encrypted in etcd"
  exit 1
fi

if [[ "$(stored team-green/api-token)" != "k8s:enc:aescbc:v1:key1" ]]; then
  echo "FAIL: secret api-token in namespace team-green is not stored encrypted in etcd"
  exit 1
fi

echo "PASS: secrets are encrypted at rest with aescbc key1, including the existing team-green secrets"
