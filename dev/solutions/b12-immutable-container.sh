#!/usr/bin/env bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl -n immutable patch deployment frontend --type=strategic -p '
spec:
  template:
    spec:
      containers:
      - name: nginx
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
        volumeMounts:
        - {name: cache, mountPath: /var/cache/nginx}
        - {name: run, mountPath: /var/run}
        - {name: tmp, mountPath: /tmp}
      volumes:
      - {name: cache, emptyDir: {}}
      - {name: run, emptyDir: {}}
      - {name: tmp, emptyDir: {}}
'
kubectl -n immutable rollout status deployment frontend --timeout=90s
