#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl delete clusterrolebinding deployer-admin
kubectl -n ci create role deployer-role --verb=get,list,watch,create,update,patch --resource=deployments.apps
kubectl -n ci patch role deployer-role --type=json -p '[{"op":"add","path":"/rules/-","value":{"apiGroups":[""],"resources":["pods"],"verbs":["get","list"]}}]'
kubectl -n ci create rolebinding deployer-rb --role=deployer-role --serviceaccount=ci:deployer
kubectl -n ci patch deployment ci-runner -p '{"spec":{"template":{"spec":{"automountServiceAccountToken":false}}}}'
kubectl -n ci rollout status deployment ci-runner --timeout=60s
