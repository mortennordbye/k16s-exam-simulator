#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
cat > /etc/falco/config.d/k16s-file-output.yaml <<'EOF'
file_output:
  enabled: true
  keep_alive: false
  filename: /var/log/falco/alerts.log
EOF
cat >> /etc/falco/falco_rules.local.yaml <<'EOF'

- rule: Read sensitive file untrusted
  output: SENSITIVE-READ file=%fd.name user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name
  override:
    output: replace
EOF
systemctl restart falco
sleep 8
systemctl is-active falco
