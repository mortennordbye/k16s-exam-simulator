#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: deny-all-ingress, namespace: netpol-internal}
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: worker-egress-internal, namespace: netpol-internal}
spec:
  podSelector: {matchLabels: {role: worker}}
  policyTypes: [Egress]
  egress:
  - to: [{podSelector: {matchLabels: {role: api}}}]
    ports: [{protocol: TCP, port: 7000}]
  - to: [{podSelector: {matchLabels: {role: metrics}}}]
    ports: [{protocol: TCP, port: 9100}]
EOF
