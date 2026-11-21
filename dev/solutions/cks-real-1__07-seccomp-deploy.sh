#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl -n seccomp-apps patch deployment seccomp-app -p '{"spec":{"template":{"spec":{"securityContext":{"seccompProfile":{"type":"RuntimeDefault"}}}}}}'
kubectl -n seccomp-apps rollout status deployment seccomp-app --timeout=90s
