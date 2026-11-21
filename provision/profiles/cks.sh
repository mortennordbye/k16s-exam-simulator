#!/usr/bin/env bash
# CKS profile extras: security tools used by the CKS tasks.
# Idempotent: each tool is installed only when the pinned version is missing.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"

log_step "CKS profile extras"

TRIVY_VERSION="0.76.2"
KUBE_BENCH_VERSION="0.16.0"
BOM_VERSION="0.8.0"
KUBESEC_VERSION="2.15.0"
KUBE_LINTER_VERSION="0.8.3"
FALCO_VERSION="0.45.2"
GVISOR_RELEASE="20261116"

case "$(uname -m)" in
  aarch64|arm64) ARCH=arm64; TRIVY_ARCH=ARM64; FALCO_ARCH=aarch64; GV_ARCH=aarch64; KL_SUFFIX="_arm64" ;;
  x86_64|amd64)  ARCH=amd64; TRIVY_ARCH=64bit; FALCO_ARCH=x86_64;  GV_ARCH=x86_64;  KL_SUFFIX="" ;;
  *) die "unsupported architecture $(uname -m)" ;;
esac

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }

# ── etcdctl environment (same as the CKA profile) ──────────────────────────
if [[ -f /etc/kubernetes/pki/etcd/ca.crt ]] && ! grep -q ETCDCTL_CACERT /home/candidate/.bashrc 2>/dev/null; then
  cat >> /home/candidate/.bashrc <<EOF

export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
EOF
  log_ok "etcdctl environment variables set for candidate"
fi

# ── trivy + vulnerability DB ────────────────────────────────────────────────
if [[ "$(trivy --version 2>/dev/null | awk '/^Version/{print $2}')" != "${TRIVY_VERSION}" ]]; then
  fetch "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" "$TMP/trivy.tgz"
  tar -xzf "$TMP/trivy.tgz" -C "$TMP" trivy
  install -m 0755 "$TMP/trivy" /usr/local/bin/trivy
  log_ok "trivy ${TRIVY_VERSION} installed"
else
  log_skip "trivy ${TRIVY_VERSION}"
fi
# One shared DB in /var/lib/trivy: root uses it as its cache, the candidate
# gets an own cache dir whose db/ points to the shared DB (fanal.db stays per user).
mkdir -p /var/lib/trivy
rm -f /etc/profile.d/trivy.sh
if [[ ! -f /var/lib/trivy/db/trivy.db ]] || [[ -n "$(find /var/lib/trivy/db/trivy.db -mmin +720 2>/dev/null)" ]]; then
  TRIVY_CACHE_DIR=/var/lib/trivy trivy image --download-db-only --no-progress >/dev/null 2>&1 \
    && log_ok "trivy DB downloaded to /var/lib/trivy" || log_warn "trivy DB download failed (tasks will download it on first use)"
else
  log_skip "trivy DB"
fi
chmod -R a+rwX /var/lib/trivy/db 2>/dev/null || true
mkdir -p /root/.cache
[[ -e /root/.cache/trivy ]] || ln -s /var/lib/trivy /root/.cache/trivy
if id candidate >/dev/null 2>&1; then
  CH=$(getent passwd candidate | cut -d: -f6)
  [[ -L "$CH/.cache/trivy" ]] && rm -f "$CH/.cache/trivy"
  mkdir -p "$CH/.cache/trivy"
  [[ -e "$CH/.cache/trivy/db" ]] || ln -s /var/lib/trivy/db "$CH/.cache/trivy/db"
  chown -R candidate: "$CH/.cache"
fi

# ── kube-bench ──────────────────────────────────────────────────────────────
if [[ "$(kube-bench version 2>/dev/null)" != "${KUBE_BENCH_VERSION}" ]]; then
  fetch "https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}/kube-bench_${KUBE_BENCH_VERSION}_linux_${ARCH}.tar.gz" "$TMP/kb.tgz"
  mkdir -p "$TMP/kb" && tar -xzf "$TMP/kb.tgz" -C "$TMP/kb"
  install -m 0755 "$TMP/kb/kube-bench" /usr/local/bin/kube-bench
  rm -rf /etc/kube-bench/cfg && mkdir -p /etc/kube-bench && cp -r "$TMP/kb/cfg" /etc/kube-bench/cfg
  log_ok "kube-bench ${KUBE_BENCH_VERSION} installed (config in /etc/kube-bench/cfg)"
else
  log_skip "kube-bench ${KUBE_BENCH_VERSION}"
fi

# ── bom (SPDX SBOM generator) ───────────────────────────────────────────────
if ! bom version 2>/dev/null | grep -q "v${BOM_VERSION}"; then
  fetch "https://github.com/kubernetes-sigs/bom/releases/download/v${BOM_VERSION}/bom-${ARCH}-linux" "$TMP/bom"
  install -m 0755 "$TMP/bom" /usr/local/bin/bom
  log_ok "bom ${BOM_VERSION} installed"
else
  log_skip "bom ${BOM_VERSION}"
fi

# ── kubesec ─────────────────────────────────────────────────────────────────
if ! kubesec version 2>/dev/null | grep -q "${KUBESEC_VERSION}"; then
  fetch "https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_linux_${ARCH}.tar.gz" "$TMP/kubesec.tgz"
  tar -xzf "$TMP/kubesec.tgz" -C "$TMP" kubesec
  install -m 0755 "$TMP/kubesec" /usr/local/bin/kubesec
  log_ok "kubesec ${KUBESEC_VERSION} installed"
else
  log_skip "kubesec ${KUBESEC_VERSION}"
fi

# ── kube-linter ─────────────────────────────────────────────────────────────
if ! kube-linter version 2>/dev/null | grep -q "${KUBE_LINTER_VERSION}"; then
  fetch "https://github.com/stackrox/kube-linter/releases/download/v${KUBE_LINTER_VERSION}/kube-linter-linux${KL_SUFFIX}" "$TMP/kube-linter"
  install -m 0755 "$TMP/kube-linter" /usr/local/bin/kube-linter
  log_ok "kube-linter ${KUBE_LINTER_VERSION} installed"
else
  log_skip "kube-linter ${KUBE_LINTER_VERSION}"
fi

# ── Falco (modern eBPF, installed but not started; tasks start it) ─────────
if ! falco --version 2>/dev/null | grep -q "Falco version: ${FALCO_VERSION}"; then
  fetch "https://download.falco.org/packages/bin/${FALCO_ARCH}/falco-${FALCO_VERSION}-${FALCO_ARCH}.tar.gz" "$TMP/falco.tgz"
  tar -xzf "$TMP/falco.tgz" -C "$TMP"
  # keep local rule edits on re-install
  cp -rn "$TMP/falco-${FALCO_VERSION}-${FALCO_ARCH}/etc/." /etc/ 2>/dev/null || true
  cp -r "$TMP/falco-${FALCO_VERSION}-${FALCO_ARCH}/usr/." /usr/
  log_ok "falco ${FALCO_VERSION} installed"
else
  log_skip "falco ${FALCO_VERSION}"
fi
if [[ ! -f /etc/systemd/system/falco.service ]]; then
  cat > /etc/systemd/system/falco.service <<'EOF'
[Unit]
Description=Falco runtime security (modern eBPF)
After=network.target containerd.service

[Service]
Type=simple
ExecStart=/usr/bin/falco -o engine.kind=modern_ebpf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  log_ok "falco.service unit written (not enabled)"
fi

# ── gVisor (runsc) + containerd runtime handler ────────────────────────────
if ! runsc --version 2>/dev/null | grep -q "release-${GVISOR_RELEASE}"; then
  base="https://storage.googleapis.com/gvisor/releases/release/${GVISOR_RELEASE}/${GV_ARCH}"
  fetch "$base/gvisor.tar.bz2" "$TMP/gvisor.tar.bz2"
  fetch "$base/gvisor.tar.bz2.sha512" "$TMP/gvisor.tar.bz2.sha512"
  (cd "$TMP" && sha512sum -c gvisor.tar.bz2.sha512 >/dev/null) || die "gVisor checksum mismatch"
  command -v bzip2 >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq bzip2 >/dev/null 2>&1
  mkdir -p "$TMP/gv" && tar -xjf "$TMP/gvisor.tar.bz2" -C "$TMP/gv"
  install -m 0755 "$TMP/gv/runsc" /usr/local/bin/runsc
  install -m 0755 "$TMP/gv/containerd-shim-runsc-v1" /usr/local/bin/containerd-shim-runsc-v1
  if [[ -d "$TMP/gv/gvisor-bin" ]]; then
    rm -rf /usr/local/bin/gvisor-bin && cp -r "$TMP/gv/gvisor-bin" /usr/local/bin/gvisor-bin
  fi
  log_ok "gVisor ${GVISOR_RELEASE} installed"
else
  log_skip "gVisor ${GVISOR_RELEASE}"
fi
mkdir -p /etc/containerd/conf.d
if [[ ! -f /etc/containerd/conf.d/runsc.toml ]]; then
  cat > /etc/containerd/conf.d/runsc.toml <<'EOF'
version = 3
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]
  runtime_type = 'io.containerd.runsc.v1'
EOF
  systemctl restart containerd
  log_ok "containerd runtime handler runsc added"
else
  log_skip "containerd runsc handler"
fi

log_ok "CKS profile configured"
