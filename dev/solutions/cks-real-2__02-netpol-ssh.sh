#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
cat > /opt/cks-netpol/allow-ssh-office.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-ssh-office, namespace: netpol-ssh}
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
  - from:
    - ipBlock: {cidr: 203.0.113.0/24, except: [203.0.113.128/25]}
    ports: [{protocol: TCP, port: 22}]
EOF
kubectl apply -f /opt/cks-netpol/allow-ssh-office.yaml
