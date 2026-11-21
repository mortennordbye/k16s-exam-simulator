# CKS bank: test results

Lab: Lima VM `k16s` (controlplane, Ubuntu 24.04 arm64, kubeadm v1.37.2, containerd 2.4.2, Calico),
workers node01/node02 (Incus LXC). Tested on 2026-11-21.

Method per task: setup.sh twice (idempotent), validate.sh must fail, run the reference solution in
`dev/solutions/<id>.sh`, validate.sh must pass, then one partial solution must give some FAIL lines,
not all. validate.sh ran through a local copy of the server wrapper (exit 1 counts a failed check and
the script goes on). Every kube-apiserver change was reverted from a backup kept outside
`/etc/kubernetes/manifests` (`/root/k16s-backup/kube-apiserver.yaml.orig`, restored file is identical).

| Task | Checks | Setup (x2) | Fails before | Passes after | Partial | Notes |
|---|---|---|---|---|---|---|
| b01-audit-policy | 6 | OK | 6/6 fail | OK | 2/6 fail (catch-all Metadata, no maxage) | Checks read the real audit log after probe requests. Setup restarts the apiserver only when audit flags are left from an earlier run (about 47 s). |
| b02-encryption-at-rest | 5 | OK | 5/5 fail | OK | 2/5 fail (secrets not rewritten) | Checks read etcd with etcdctl. Setup cannot undo encryption: after a solved run, new secrets are already encrypted. Test cleanup: identity first, rewrite all secrets, remove flag. |
| b03-image-policy-webhook | 6 | OK | 5/6 fail | OK | 3/6 fail (kubeconfig server not fixed) | Setup runs a small HTTPS review backend (systemd `k16s-image-bouncer`, 127.0.0.1:8443). It denies `latest` only in namespace team-red, so other tasks keep working. While defaultAllow is false and the backend is down, no pod can be created in the whole cluster. |
| b04-trivy-critical | 4 | OK | 3/4 fail | OK | 3/4 fail | nginx:1.14.0, redis:5.0.0, httpd:2.4.39 have CRITICAL findings; pause:3.10 and busybox:1.37 have none (trivy 0.76.2). |
| b05-sbom-spdx | 4 | OK | 3/4 fail | OK | 2/4 fail | bom 0.8.0 and trivy spdx-json both pass. busybox 1.36.1-r15 is only in alpine:3.19.1. |
| b06-static-analysis | 6 | OK | 5/6 fail | OK | 3/6 fail | kubesec 2.15.0 runs on the file and on the live pod. |
| b07-runtimeclass-gvisor | 5 | OK | 5/5 fail | OK | 4/5 fail (RuntimeClass only) | gVisor works on the controlplane VM (runsc release-20261116, arm64). dmesg shows gVisor. Workers (LXC) have no runsc: pods are pinned to controlplane. |
| b08-psa-restricted | 5 | OK | 4/5 fail | OK | 3/5 fail (enforce label only) | Pod check evaluates the restricted rules on the running pods. |
| b09-rbac-serviceaccount | 5 | OK | 5/5 fail | OK | 3/5 fail (Role with delete, no pods rule) | Uses kubectl auth can-i --as. |
| b10-secret-volume | 5 | OK | 4/5 fail | OK | 3/5 fail (token file only) | |
| b11-ingress-tls | 5 | OK | 5/5 fail | OK | 2/5 fail (no tls block, no class) | No ingress controller needed. |
| b12-immutable-container | 4 | OK | 3/4 fail | OK | 3/4 fail (readOnly without emptyDirs: CrashLoop) | |
| b13-verify-binaries | 3 | OK | 2/3 fail | OK | 1/3 fail | Offline. Real kubectl/kubelet/kubeadm copies plus two stand-in files. |
| b14-falco-find-pod | 3 | OK | 2/3 fail | OK | 1/3 fail | Falco 0.45.2 modern_ebpf works on kernel 6.8 arm64 (tracepoint warnings for open/creat are normal on arm64). Alerts carry k8s_pod_name and k8s_ns_name. |
| b15-falco-rule-output | 4 | OK | 3/4 fail | OK | 2/4 fail (file output only) | Setup resets /etc/falco to a copy taken on first run. |
| b16-apiserver-anon-noderestriction | 6 | OK | 5/6 fail | OK | 2/6 fail (NodeRestriction + --anonymous-auth=false) | Setup always restarts the apiserver (removes NodeRestriction), about 45 s. Uses AuthenticationConfiguration with anonymous conditions for /livez, /readyz, /healthz. |

## Limits and findings

- `--anonymous-auth=false` breaks the kubeadm probes: /livez and /readyz answer 401, the pod stays not ready
  and the startup probe restarts the apiserver after a few minutes. b16 uses an AuthenticationConfiguration instead.
  The existing task `cks3/04-cis-apiserver-anon` asks for `--anonymous-auth=false`: it is not used in the mocks.
- Every apiserver restart makes kube-controller-manager and kube-scheduler lose their lease and restart, with a
  growing CrashLoop back-off after many restarts. Until they are back, new namespaces get no default
  ServiceAccount and Deployments get no pods. In the mocks b16 is the last task, so its setup runs last.
- Setup time: all setups take 0 to 3 s, except b16 (about 45 s) and a rerun of b01/b03 after a solved run
  (up to about 50 s, waiting for the apiserver). The server allows 120 s.
- `cks3/07-cis-etcd-cert-auth` setup edits the etcd manifest (etcd and apiserver restart): not used in the mocks.
- Copied `cks3/01-cis-kube-bench-master` (cks-real-1/02): the original counts `^FAIL` lines, but kube-bench
  0.16.0 prints `[FAIL]`. Fixed in the copy only (hint and check). Tested pass and partial.
- Copied `cks3/11-netpol-multi` (cks-real-2/01): a FAIL inside a loop made the count 7/6. Unrolled in the copy.
- Tools: `provision/profiles/cks.sh` installs trivy 0.76.2 (+ DB in /var/lib/trivy), kube-bench 0.16.0,
  bom 0.8.0, kubesec 2.15.0, kube-linter 0.8.3, Falco 0.45.2 (service `falco`, not enabled; tasks start it),
  gVisor 20261116 (runsc + containerd handler `runsc`). Run twice in the VM: second run skips everything.

## Mock exam smoke test

All setup.sh of cks-real-1, -2, -3 ran in task order on one cluster: all rc=0. After that every validate.sh
failed (no task passes before work).
