#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
F=/opt/cks-sbom/nginx.spdx.json

if ! python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d['spdxVersion'].startswith('SPDX-')" "$F" 2>/dev/null; then
  echo "FAIL: $F is missing or is not an SPDX JSON document"
  exit 1
fi

if ! python3 - "$F" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
names = {p.get("name", "") for p in d.get("packages", [])}
assert len(names) > 5 and "nginx" in names and "musl" in names
PY
then
  echo "FAIL: the SBOM does not list the packages of image nginx:1.27-alpine"
  exit 1
fi

if kubectl -n sbom get deployment beta >/dev/null 2>&1; then
  echo "FAIL: deployment beta (its image contains busybox 1.36.1-r15) still exists"
  exit 1
fi

if [[ "$(kubectl -n sbom get deployment alpha -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)" != "alpine:3.18.6" ]] ||
   [[ "$(kubectl -n sbom get deployment gamma -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)" != "alpine:3.20.3" ]]; then
  echo "FAIL: deployments alpha and gamma must stay unchanged"
  exit 1
fi

echo "PASS: SPDX SBOM saved and the deployment with busybox 1.36.1-r15 is deleted"
