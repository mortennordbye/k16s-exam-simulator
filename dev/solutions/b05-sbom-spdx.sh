#!/usr/bin/env bash
# Reference solution for b05-sbom-spdx
export KUBECONFIG=/etc/kubernetes/admin.conf
export TRIVY_CACHE_DIR=/var/lib/trivy
bom generate --image nginx:1.27-alpine --format json --output /opt/cks-sbom/nginx.spdx.json 2>/dev/null
for d in alpha beta gamma; do
  img=$(kubectl -n sbom get deploy $d -o jsonpath='{.spec.template.spec.containers[0].image}')
  trivy image -q --format spdx-json "$img" > /tmp/$d.json
  if grep -q '"versionInfo": "1.36.1-r15"' /tmp/$d.json; then echo "$d $img"; kubectl -n sbom delete deploy $d; fi
done
