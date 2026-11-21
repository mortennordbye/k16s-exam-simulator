#!/usr/bin/env bash
set -eo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

# Falco is installed by provision/profiles/cks.sh (modern eBPF, service falco).
if ! command -v falco >/dev/null || [[ ! -f /etc/systemd/system/falco.service ]]; then
  echo "falco is not installed: run provision/profiles/cks.sh" >&2
  exit 1
fi

systemctl start falco
mkdir -p /opt/cks-falco
rm -f /opt/cks-falco/suspicious-pod.txt
app() { # ns name script
  kubectl create namespace "$1" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n "$1" create configmap "$2-script" --from-literal=run.sh="$3" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $2
  namespace: $1
spec:
  replicas: 1
  selector:
    matchLabels: {app: $2}
  template:
    metadata:
      labels: {app: $2}
    spec:
      nodeSelector:
        kubernetes.io/hostname: controlplane
      containers:
      - name: $2
        image: busybox:1.37
        command: ["sh", "/app/run.sh"]
        volumeMounts:
        - {name: script, mountPath: /app}
      volumes:
      - name: script
        configMap: {name: $2-script}
EOF
}
app frontend web-cache 'while true; do date > /tmp/last; ls /tmp >/dev/null; sleep 5; done'
app finance  reporter  'while true; do head -c 64 /etc/shadow >/dev/null 2>&1; sleep 4; done'
app metrics  collector 'while true; do cat /proc/loadavg >/dev/null; sleep 5; done'
kubectl -n finance scale deployment reporter --replicas=1 >/dev/null
echo "Environment ready: Falco is running on controlplane"
