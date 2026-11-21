#!/usr/bin/env bash
# Pull Docker Hub images through mirror.gcr.io (Google's public cache of
# Docker Hub). Anonymous Docker Hub pulls are rate limited (about 100 per
# 6 h per IP), and a rebuild plus a mock can pass that limit. containerd
# falls back to Docker Hub when the mirror does not have an image.
# Idempotent. Runs on the control plane and inside each worker.
set -euo pipefail

mkdir -p /etc/containerd/certs.d/docker.io
cat > /etc/containerd/certs.d/docker.io/hosts.toml <<'EOF'
server = "https://registry-1.docker.io"

[host."https://mirror.gcr.io"]
  capabilities = ["pull", "resolve"]
EOF

CFG=/etc/containerd/config.toml
[[ -f "$CFG" ]] || exit 0
if grep -q "config_path = ''" "$CFG"; then
  sed -i "s#config_path = ''#config_path = '/etc/containerd/certs.d'#" "$CFG"
  systemctl restart containerd
fi
