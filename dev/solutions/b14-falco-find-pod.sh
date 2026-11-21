#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
sleep 10
L=$(journalctl -u falco --since "-5min" --no-pager | grep '/etc/shadow' | grep -o 'k8s_pod_name=[^ ]* k8s_ns_name=[^ ]*' | tail -1)
POD=$(echo "$L" | sed 's/k8s_pod_name=\([^ ]*\) .*/\1/'); NS=$(echo "$L" | sed 's/.*k8s_ns_name=//')
echo "found $NS/$POD"
OWNER=$(kubectl -n $NS get pod $POD -o jsonpath='{.metadata.ownerReferences[0].name}')
DEP=$(kubectl -n $NS get rs $OWNER -o jsonpath='{.metadata.ownerReferences[0].name}')
echo "$NS/$POD" > /opt/cks-falco/suspicious-pod.txt
kubectl -n $NS scale deployment $DEP --replicas=0
kubectl -n $NS wait --for=delete pod/$POD --timeout=60s
