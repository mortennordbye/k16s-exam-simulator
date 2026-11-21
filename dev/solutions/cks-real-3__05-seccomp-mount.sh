#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
cat > /var/lib/kubelet/seccomp/profiles/block-mount.json <<'EOF'
{"defaultAction": "SCMP_ACT_ALLOW", "syscalls": [{"names": ["mount", "umount2"], "action": "SCMP_ACT_ERRNO"}]}
EOF
kubectl -n seccomp-mount patch deployment mount-block --type=merge -p '{"spec":{"template":{"spec":{"securityContext":{"seccompProfile":{"type":"Localhost","localhostProfile":"profiles/block-mount.json"}}}}}}'
kubectl -n seccomp-mount rollout status deployment mount-block --timeout=90s
