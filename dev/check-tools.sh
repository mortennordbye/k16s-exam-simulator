#!/usr/bin/env bash
for t in trivy kube-bench bom kubesec kube-linter falco runsc containerd-shim-runsc-v1; do
  printf '%s: ' "$t"; command -v "$t" || echo MISSING
done
