#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl label ns secure-apps pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/warn=restricted --overwrite
kubectl -n secure-apps patch deployment web --type=strategic -p '{"spec":{"template":{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"web","securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}}}'
kubectl -n secure-apps rollout status deployment web --timeout=90s
