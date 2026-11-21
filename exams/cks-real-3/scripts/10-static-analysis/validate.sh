#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
F=/opt/cks-static/reporting.yaml
D=/opt/cks-static/Dockerfile
TMP=$(mktemp)
kubectl -n static get pod reporting -o yaml > "$TMP" 2>/dev/null
# usage: ks <file> -> prints "critical-count passed-ids..."
ks() { kubesec scan "$1" 2>/dev/null | python3 -c '
import sys, json
d = json.load(sys.stdin)[0]
s = d.get("scoring", {})
print(len(s.get("critical") or []), " ".join(x["id"] for x in s.get("passed") or []))' 2>/dev/null; }
LIVE=$(ks "$TMP"); FILE=$(ks "$F")
rm -f "$TMP"
good() { [[ "$1" == 0\ * ]] && for c in RunAsNonRoot CapDropAll LimitsMemory; do [[ " $1 " == *" $c "* ]] || return 1; done; }

if [[ "$(kubectl -n static get pod reporting -o jsonpath='{.status.phase}' 2>/dev/null)" != "Running" ]] ||
   [[ "$(kubectl -n static get pod reporting -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)" != "nginxinc/nginx-unprivileged:1.27-alpine" ]]; then
  echo "FAIL: pod reporting in namespace static is not Running with image nginxinc/nginx-unprivileged:1.27-alpine"
  exit 1
fi

if [[ "$LIVE" != 0\ * && "$LIVE" != "0" ]]; then
  echo "FAIL: kubesec still reports critical findings for the running pod reporting"
  exit 1
fi

if ! good "$LIVE" || ! good "$FILE"; then
  echo "FAIL: kubesec must show RunAsNonRoot, CapDropAll and LimitsMemory as passed for $F and the running pod"
  exit 1
fi

if ! grep -qE '^FROM[[:space:]]+(docker\.io/(library/)?)?ubuntu:24\.04([[:space:]]|$)' "$D" 2>/dev/null; then
  echo "FAIL: $D must use the base image ubuntu:24.04"
  exit 1
fi

if [[ ! -f "$D" ]] || grep -q 'Sup3rS3cret' "$D" || grep -qiE '^(ENV|ARG).*PASSWORD' "$D"; then
  echo "FAIL: $D still contains the hard-coded password"
  exit 1
fi

LASTUSER=$(grep -iE '^USER[[:space:]]' "$D" 2>/dev/null | tail -1 | awk '{print $2}')
if [[ "$LASTUSER" != "appuser" && "$LASTUSER" != "10001" ]] || ! grep -q 'useradd -u 10001 -m appuser' "$D"; then
  echo "FAIL: $D must run the container as appuser (last USER instruction)"
  exit 1
fi

echo "PASS: kubesec findings are fixed for the reporting pod and the Dockerfile is hardened"
