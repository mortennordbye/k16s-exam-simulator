#!/usr/bin/env bash
# yq (mikefarah) is on every exam host in the real CKS. Pinned, idempotent.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

YQ_VERSION="${K16S_YQ_VERSION:-v4.54.3}"
if yq --version 2>/dev/null | grep -q "${YQ_VERSION}"; then
  log_skip "yq ${YQ_VERSION}"
  exit 0
fi
ARCH=$(dpkg --print-architecture)
curl -fsSL --retry 3 -o /usr/local/bin/yq \
  "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}"
chmod 0755 /usr/local/bin/yq
log_ok "yq ${YQ_VERSION} installed"
