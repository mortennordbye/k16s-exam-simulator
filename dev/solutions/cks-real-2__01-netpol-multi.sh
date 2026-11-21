#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl label namespace dmz zone=dmz --overwrite
kubectl label namespace internal zone=internal --overwrite
cat > /opt/cks3-netpol/restrict-ingress-egress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-ingress-egress
  namespace: netpol-multi
spec:
  podSelector: {matchLabels: {app: app1}}
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - namespaceSelector: {matchLabels: {zone: dmz}}
      podSelector: {matchLabels: {role: client}}
    ports: [{protocol: TCP, port: 8080}]
  egress:
  - to:
    - namespaceSelector: {matchLabels: {zone: internal}}
      podSelector: {matchLabels: {role: db}}
    ports: [{protocol: TCP, port: 3306}]
  - to:
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}
      podSelector: {matchLabels: {k8s-app: kube-dns}}
    ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
EOF
kubectl apply -f /opt/cks3-netpol/restrict-ingress-egress.yaml
