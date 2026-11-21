#!/usr/bin/env bash
# Runs as root on controlplane; does the work on cilium-cp over ssh.
ssh cilium-cp bash -s <<'EOF'
export KUBECONFIG=/etc/kubernetes/admin.conf
cat <<'YAML' | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: {name: backend-ingress, namespace: team-blue}
spec:
  endpointSelector: {matchLabels: {app: backend}}
  ingress:
  - fromEndpoints: [{matchLabels: {app: frontend}}]
    toPorts: [{ports: [{port: "80", protocol: TCP}]}]
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: {name: backend-deny-database, namespace: team-blue}
spec:
  endpointSelector: {matchLabels: {app: backend}}
  egress:
  - toEntities: [all]
  egressDeny:
  - toEndpoints: [{matchLabels: {app: database}}]
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: {name: frontend-deny-world, namespace: team-blue}
spec:
  endpointSelector: {matchLabels: {app: frontend}}
  enableDefaultDeny: {egress: false}
  egressDeny:
  - toEntities: [world]
YAML
sleep 5
EOF
