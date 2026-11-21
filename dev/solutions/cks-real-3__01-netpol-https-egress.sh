#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: deny-all-egress, namespace: netpol-external}
spec:
  podSelector: {}
  policyTypes: [Egress]
EOF
cat > /opt/cks3-netpol/allow-external-https.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-external-https, namespace: netpol-external}
spec:
  podSelector: {matchLabels: {app: client}}
  policyTypes: [Egress]
  egress:
  - to:
    - ipBlock: {cidr: 0.0.0.0/0, except: [169.254.169.254/32, 10.10.0.0/16]}
    ports: [{protocol: TCP, port: 443}]
  - to:
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}
    ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
EOF
kubectl apply -f /opt/cks3-netpol/allow-external-https.yaml
