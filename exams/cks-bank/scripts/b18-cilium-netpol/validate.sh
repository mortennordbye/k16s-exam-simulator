#!/usr/bin/env bash
# Runs as root on controlplane. Sends real traffic between the pods on cilium-cp.
R() { ssh -o BatchMode=yes -o ConnectTimeout=5 cilium-cp "$@" 2>/dev/null; }
K="kubectl --kubeconfig /etc/kubernetes/admin.conf -n team-blue"
# probe <from-deployment> <url>: prints ok or blocked
probe() { if R "$K exec deploy/$1 -- wget -qO- -T 3 $2 >/dev/null"; then echo ok; else echo blocked; fi; }
cnp() { R "$K get ciliumnetworkpolicy $1 -o yaml"; }
# An address outside cluster cilium: the main VM (controlplane, nginx on port 80).
WORLD="http://$(ip route get 8.8.8.8 | grep -oP 'src \K\S+')"

if ! cnp backend-ingress | grep -qE "port: \"?80\"?" || [[ "$(probe other backend)" != blocked ]]; then
  echo "FAIL: CiliumNetworkPolicy backend-ingress (TCP 80 from app=frontend only) is missing, or pods of other still reach backend"
  exit 1
fi

if [[ "$(probe frontend backend)" != ok ]]; then
  echo "FAIL: pods of frontend cannot reach backend on port 80"
  exit 1
fi

if ! cnp backend-deny-database | grep -q egressDeny || [[ "$(probe backend database)" != blocked ]]; then
  echo "FAIL: CiliumNetworkPolicy backend-deny-database (egressDeny) is missing, or backend still reaches database"
  exit 1
fi

if [[ "$(probe backend other)" != ok || "$(probe other database)" != ok ]]; then
  echo "FAIL: other traffic is blocked too: backend must still reach other, and other must reach database"
  exit 1
fi

if ! cnp frontend-deny-world | grep -q world || [[ "$(probe frontend "$WORLD")" != blocked ]]; then
  echo "FAIL: CiliumNetworkPolicy frontend-deny-world (egressDeny to entity world) is missing, or frontend still reaches addresses outside the cluster"
  exit 1
fi

if [[ "$(probe frontend database)" != ok || "$(probe other "$WORLD")" != ok ]]; then
  echo "FAIL: other traffic is blocked too: frontend must still reach database, and other must reach addresses outside the cluster"
  exit 1
fi

echo "PASS: CiliumNetworkPolicies allow frontend to backend on port 80, deny backend to database and frontend to world"
