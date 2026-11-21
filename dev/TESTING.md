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

## Review fixes

Source: `plans/02-task-review.md`. Tested on 2026-11-21 on a fresh lab cluster (v1.37.2). Method per task:
setup.sh twice, wait 20 s, validate.sh (wrapped like the server) must fail, run the reference solution,
validate.sh must pass, then setup again plus one wrong but tempting answer: at least one check must fail.
Static pod manifests were backed up to `/root/k16s-review/backup/` in the VM and restored (cmp identical).
The cluster was healthy after the tests (all nodes Ready, control plane pods 1/1, /readyz ok).

| Task | Change | After setup | Solution | Wrong answer (result) |
|---|---|---|---|---|
| real-1/01-netpol-microseg | check podSelector {} of deny-all-ingress | 9/9 fail | pass | deny-all selects role=worker: 1 fail |
| real-1/02-cis-kube-bench-master | new task: fix 1.3.2 and 1.4.1 (profiling of controller-manager and scheduler), checks the running process and pod Ready; weight 5 | 4/4 fail | pass | scheduler not fixed: 1 fail |
| real-1/05-pki-csr | key check; CSR API flow (approve, save alice.crt) | 8/8 fail | pass | CSR from other key: 3 fail; openssl only: 2 fail |
| real-1/06-apparmor-load | test command with 2>&1; container name deny-etc; live write test | 5/5 fail | pass | old command: 1 fail; no profile + hand-made file: 2 fail |
| real-1/07-seccomp-deploy | busywork step removed; rollout folded into the type check; weight 3 | 1/1 fail | pass | seccomp on container level: 1 fail |
| b09 + real-1/04, real-2/04, real-3/03 rbac | accepts removing the CRB subject and automount false on the SA; setup resets the SA field | 5/5 fail | pass (all 4 copies) | alt answer (CRB subject removed, SA automount false): pass; CRB deleted only: 4 fail; SA field without pod restart: 1 fail |
| real-2/01-netpol-multi | DNS to CoreDNS in kube-system on UDP+TCP 53; policyTypes check; saved file must hold the policy | 8/8 fail | pass | old same-namespace DNS rule: 1 fail |
| real-2/02-netpol-ssh | per-rule port + ipBlock; podSelector {} | 3/3 fail | pass | port and ipBlock in two rules: 1 fail; app=sshd selector: 1 fail |
| real-2/05-cis-apiserver-profiling | CIS 1.2.15; checks the running kube-apiserver (ps args) and /readyz; busywork step removed | 1/1 fail | pass | flag only in a copy of the manifest: 1 fail |
| real-2/06-aa-deny-tmp (was 07-aa-read-hosts) | rework: load given profile file, profile name differs from file name, live /tmp write test; busywork step removed | 3/3 fail | pass | file name used as profile name: 2 fail |
| real-2/07-seccomp-mkdir | copy step removed; exact localhostProfile; live mkdir test | 5/5 fail | pass | only mkdir blocked (arm64 uses mkdirat): 2 fail |
| real-3/01-netpol-https-egress | deny-all-egress content; podSelector app=client; DNS to kube-system UDP+TCP 53 | 6/6 fail | pass | allow-all rule in deny policy + DNS UDP only: 2 fail |
| real-3/04-hardened-pod | container name app and image checked | 4/4 fail | pass | seccomp on container level: 1 fail |
| real-3/05-seccomp-mount | copy step removed; exact profile; rollout complete folded into the check | 3/4 fail | pass | patch without profile file (old pod runs): 3 fail incl. rollout |

Guards (no script change, the server now counts a broken guard as a lost item), wrong answer tested on the real-1 copy:
trivy delete all pods (FAIL@4), verify-binaries `rm *` (FAIL@3), sbom delete all deployments (FAIL@4),
falco scale all to 0 (FAIL@2), immutable readOnly without emptyDirs (FAIL@1, 3, 4).

Dropped: real-2/05-pki-csr-san, real-3/02-netpol-metadata, real-3/05-pki-cert-key-match. Later tasks renumbered.
New weights: real-2 (sum 98) CS 18, CH 10, SH 10, MV 20, SC 20, MR 20; real-3 (sum 98) CS 13, CH 15, SH 10, MV 20,
SC 20, MR 20; real-1 stays 98. real-2 Cluster Hardening has only the RBAC task (weight 10): a second Cluster
Hardening task for real-2 and a Cluster Setup task for real-3 go to the backlog.

Findings:
- The lab kube-bench 0.16.0 maps v1.37 to `cis-1.12` (not cis-2.0). The IDs 1.2.15, 1.3.2 and 1.4.1 are correct there.
- `10.10.0.0/16` is the worker node range (node01/node02 have 10.10.0.11/12), not the pod CIDR. real-3/01 now says "internal range".
- The server wrapper keeps `set -o pipefail`: a check like `kubectl exec ... | grep -q` fails when kubectl exits non-zero. New checks capture output first.
- Mock-only solutions: `dev/solutions/<profile>__<id>.sh` (13 files).
