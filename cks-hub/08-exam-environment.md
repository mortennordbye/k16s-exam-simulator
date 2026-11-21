# Real CKS exam environment vs our lab (checked 2026-11-21)

Goal: train only on what is in the real exam. This page compares the real exam (Kubernetes v1.37) with our lab.

Claim labels:

- **Official**: Linux Foundation (LF) or CNCF page says it.
- **Candidate reports**: people who sat the exam in 2025 or 2026 say it. One or two reports only, unless the text says more.
- **Unverified**: study guides, practice repos, or our own reasoning. Nobody who sat the exam confirms it.

Main finding: LF does not publish the CNI, the container runtime, the node OS, or the full tool list. Nobody can give an exact answer for these items. The table shows the best evidence.

## 1. Real exam vs our lab

| Item | Real exam | Our lab | Gap | Confidence | Source |
|---|---|---|---|---|---|
| Kubernetes version | v1.37 | v1.37.2 | None | Official | [Important Instructions: CKS](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks), [LF CKS page](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) |
| Tasks, time | 15 to 20 tasks, 2 hours | 3 mocks | None | Official | Important Instructions |
| Hosts | Each task names a host. You `ssh <host>`, then go back to host `base`. No nested ssh. | Lima VM + Incus nodes | Small. Drill "ssh, work, exit to base" in every mock. | Official | Important Instructions |
| Root | `sudo -i` on every node | root | None | Official | Important Instructions |
| Tools on SSH hosts (official list) | kubectl with alias `k` and bash completion, `yq`, `curl`, `wget`, `man`. The `base` host has none of these. | All present | Make `base` in mocks a host with no kubectl. | Official | Important Instructions |
| Number of clusters | Several clusters. Older reports: 6 to 8. A 2025 report: kubectl contexts. Current official text: SSH per task. | 1 cluster | Medium. Only one cluster, so no "wrong cluster" trap. | Candidate reports | [jayendrapatil](https://jayendrapatil.com/certified-kubernetes-security-specialist-cks-learning-path/), [sakisv 2025](https://www.sakisv.net/2025/04/zero-to-cks-in-4-months/) |
| Cluster build | kubeadm (static pod manifests in `/etc/kubernetes/manifests`, kubelet as systemd). Every apiserver, etcd, kube-bench task depends on this. | kubeadm | None | Candidate reports (strong, many tasks need it) | All reports, killer.sh solutions |
| Container runtime | Not published. killer.sh course scripts (same author as the simulator) use containerd 2.4.2, runc, crictl, plus podman. | containerd 2.4.2 | None. Add podman for image build tasks. | Unverified for the exam. Official for the killer.sh course repo. | [killer-sh/cks-course-environment install_master.sh](https://github.com/killer-sh/cks-course-environment/blob/master/cluster-setup/latest/install_master.sh) |
| Node OS | Not published. killer.sh course scripts require Ubuntu 24.04. | Control plane Ubuntu 24.04. Workers Debian 12 LXC. | Small. LXC workers cannot load AppArmor profiles or kernel modules the same way. Do AppArmor, seccomp, Falco, gVisor on a full VM node. | Unverified | Same repo |
| CNI | Not published. A Cilium cluster must exist for at least some exam variants: a Feb 2025 candidate got a CiliumNetworkPolicy task. A Sep 2025 candidate got no Cilium task. Plain NetworkPolicy tasks also need a CNI that enforces policy (Calico or Cilium). Most likely the CNI differs per cluster. | Calico | **Medium.** No Cilium cluster, so CiliumNetworkPolicy and Cilium encryption cannot be trained. | Candidate reports (Cilium task seen once) / Unverified (exact CNI per cluster) | [bargenqua.st Feb 2025](https://bargenqua.st/posts/cks-cka-2025/), [88/100 report Sep 2025](https://medium.com/@leehosanganson/journey-to-kubestronaut-in-2025-how-did-i-score-88-100-in-cks-ccb897735ed8) |
| Cilium docs allowed | Yes: docs.cilium.io | n/a | Learn where CiliumNetworkPolicy and encryption pages are. | Official | [Resources Allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed) |
| Cilium encryption (WireGuard/IPsec), mutual auth | In the curriculum ("Implement Pod-to-Pod encryption (Cilium, Istio)"). No candidate report found of a real encryption task. | Not possible | Low value now. One short drill on a Cilium cluster is enough. | Official (in scope) / Unverified (tested) | LF CKS page, [sailor.sh 2026 guide](https://sailor.sh/blog/cks-pod-to-pod-encryption-cilium-wireguard-ipsec-transparent-encryption/) |
| Istio | In the curriculum. istio.io/latest/docs allowed. One guide reports "no mTLS questions". A 2025 practice set has "Istio mTLS and sidecar". No first hand 2025-2026 report found of an Istio task. | Not installed | Low to medium. Learn PeerAuthentication STRICT and namespace injection label. | Official (in scope) / Unverified (tested) | Resources Allowed, [jayendrapatil](https://jayendrapatil.com/certified-kubernetes-security-specialist-cks-learning-path/), [CKS-Q repo](https://github.com/AbdelrahmanAhmed655/CKS-Q) |
| Falco | Present. Tasks: change a rule, find a pod, write output to a file. Docs allowed (falco.org/docs). Install type in the exam not published. Current Falco packages install a systemd unit per driver (`falco-modern-bpf.service`, alias `falco.service`). Older killer.sh solutions read `/var/log/syslog`. | 0.45 modern_ebpf, systemd | None. Train both: journalctl and a log file target. | Official (docs allowed) / Candidate reports (tasks) / Unverified (systemd) | Resources Allowed, [Medium CKS 2026](https://medium.com/@gurbanvaliev1/cks-2026-my-path-to-the-kubernetes-security-certification-fe70d49cbc5c), [techiescamp](https://github.com/techiescamp/cks-certification-guide) |
| bom | Present (bom docs allowed). SBOM task reported in 2025. | 0.8 | None | Official (docs) / Candidate reports | Resources Allowed, bargenqua.st |
| trivy | Present. Trivy docs are NOT on the allowed list now. | 0.76 | None. Know flags without docs. | Candidate reports | sakisv 2025, killer.sh solutions |
| kube-bench | Present (CIS tasks). | 0.16 | None | Candidate reports | Medium CKS 2026 |
| etcdctl | Present (etcd docs allowed). | Present | None | Official (docs) / Candidate reports | Resources Allowed, Medium CKS 2026 |
| kubesec, kube-linter | In curriculum. No first hand report of a real task found. | Present | None | Official (in scope) / Unverified (tested, present) | LF CKS page |
| crictl, apparmor_parser, runsc | Needed by common tasks (runtime debug, AppArmor, RuntimeClass). | Present | None | Candidate reports / Unverified (runsc) | Reports, killer.sh |
| ingress-nginx | Ingress TLS tasks. ingress-nginx config docs allowed. | Present (Ingress TLS mock) | Confirm the lab has ingress-nginx, not another controller. | Official (docs) | Resources Allowed |
| cosign, helm, jq, tmux | Not on any official list. No candidate report names them as present. Exam clusters are said to have no route to public Helm repos. | No cosign | No action. Do not depend on jq or tmux. Use `yq` and `-o jsonpath`. | Unverified | sailor.sh (Helm repo claim) |
| Editor | vim is default. nano and VSCodium on the desktop. | vim | None | Official (VSCodium in ExamUI doc) / Candidate reports | [ExamUI](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2/exam-user-interface/examui-performance-based-exams), sakisv |
| killer.sh simulator | v1.37, remote XFCE desktop like the exam, 17 + 17 tasks, no URL limits. CNI not published. Its course repo (same author) installs Weave Net on kubeadm 1.37.1 + containerd 2.4.2 + Ubuntu 24.04. | | killer.sh is the best mirror we have. Use its two sessions for the Cilium and multi-cluster parts our lab lacks. | Official (killer.sh FAQ) / Unverified (simulator CNI) | [killer.sh FAQ](https://killer.sh/faq), [killer.sh/cks](https://killer.sh/cks), course repo |

## 2. Allowed docs (exact URLs, Official)

From [Resources Allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed), CKS rows:

- https://kubernetes.io/docs
- https://kubernetes.io/blog/
- https://falco.org/docs/
- https://kubernetes-sigs.github.io/bom/cli-reference/
- https://etcd.io/docs/
- https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/
- https://docs.cilium.io/
- https://istio.io/latest/docs/
- Links in each task's "Quick Reference" box
- man pages and distro docs under /usr/share

Not allowed: Trivy docs, AppArmor wiki, kube-bench docs, kubesec and kube-linter docs, GitHub.

## 3. Topics, frequency tier and confidence

Tier A: expect it. Tier B: often. Tier C: possible. Tier D: rare or gone.

| Topic | Tier | In our mocks | Confidence |
|---|---|---|---|
| NetworkPolicy (default deny, labels, DNS, metadata block) | A | Yes | Candidate reports (many) |
| apiserver hardening (anonymous-auth, NodeRestriction, admission) | A | Yes | Candidate reports (many) |
| Audit logs | A | Yes | Candidate reports (many) |
| kube-bench / CIS fixes | A | Yes | Candidate reports (many, 2026 included) |
| Falco (rule edit, output to file) | A | Yes | Candidate reports (2026) |
| RBAC and ServiceAccount (automount off) | A | Yes | Candidate reports (many) |
| Pod Security Admission / PSS | A | Yes | Official (curriculum) / Candidate reports |
| Trivy image scan, delete bad pods | A | Yes | Candidate reports (many) |
| AppArmor | A | Yes | Candidate reports (many) |
| securityContext, immutable containers | A | Yes | Official / Candidate reports |
| Secrets encryption at rest, read from etcd | B | Yes | Candidate reports (2026) |
| ImagePolicyWebhook | B | Yes | Candidate reports (2026: a fail came from its kubeconfig). Curriculum text is generic ("permitted registries"). |
| SBOM (bom, trivy spdx/cyclonedx) | B | Yes | Official / Candidate reports (Feb 2025) |
| seccomp | B | Yes | Official / Candidate reports |
| Ingress with TLS | B | Yes | Official / Candidate reports |
| Verify platform binaries (sha512sum) | B | Yes | Official / Candidate reports |
| RuntimeClass gVisor | B | Yes | Official ("sandboxed containers") / Unverified frequency. Name gVisor gone from text. |
| Kubernetes upgrade (kubeadm) | B | **No** | Official (curriculum: "Upgrade Kubernetes") / practice repos |
| kubesec, kube-linter, Dockerfile fixes | B | Yes | Official (curriculum) / Unverified (no first hand report) |
| CiliumNetworkPolicy | C | **No** | Candidate reports (1 yes, 1 no) |
| Cilium WireGuard/IPsec encryption | C | **No** | Official (in scope) / Unverified (tested) |
| Istio mTLS (PeerAuthentication STRICT) | C | **No** | Official (in scope) / Unverified (tested) |
| PKI/CSR (CertificateSigningRequest for a user) | C | Yes | Unverified for CKS (more a CKA topic). Keep short. |
| Host footprint (stop service, remove package, close port) | C | No | Official (curriculum) / Candidate reports (few) |
| Runtime attack hunt with crictl, /proc, strace | C | Partly (Falco) | Candidate reports (Sep 2025: no strace task) |
| Kubelet hardening (anonymous off, Webhook authz) | C | Partly (kube-bench) | Candidate reports |
| Docker daemon security (socket, group) | C | No | Unverified (2025 practice repo) |
| OPA Gatekeeper | D | No | No 2025-2026 report found. Not in curriculum. |
| PodSecurityPolicy | D (gone) | No | Official (removed in v1.25) |
| Old AppArmor annotation only | D (gone) | No | Official (field form GA since v1.30) |
| CIS "upgrade" tasks, Kata Containers by name | D | No | Unverified. Names gone from Oct 2024 text. |

## 4. What to change in the lab (ordered by value)

1. **Add a second small cluster with Cilium** (1 control plane VM + 1 worker, Ubuntu 24.04, kubeadm, Cilium with `kube-proxy` kept). Do not switch the main cluster: most tasks need a stable kubeadm cluster, and the CNI does not change them. Use the Cilium cluster for CiliumNetworkPolicy (including `ingressDeny`/`egressDeny`) and one WireGuard encryption drill (`cilium-dbg encrypt status`). This also gives a second kubeconfig context, so we can train the "wrong cluster" trap. Value: medium. Cost: 1 to 2 hours.
2. **Add a kubeadm upgrade task** (control plane + 1 worker). It is in the official curriculum and our mocks have none. Value: medium.
3. **Make the mock flow match the exam**: one `base` host with no kubectl; each task starts with `ssh <host>`; tasks must end with `exit` to base. Value: medium, cost low.
4. **Run AppArmor, seccomp, Falco and gVisor tasks on a full VM node, not on a Debian LXC worker.** LXC shares the host kernel and AppArmor policy, so results can differ from a real node. Value: medium.
5. **Add Istio on the Cilium cluster or the main cluster** (minimal profile). One drill: label a namespace for injection, set PeerAuthentication STRICT, prove plain text calls fail. Value: low to medium.
6. **Add 2 short tasks**: host footprint (find and stop a service, close a port) and Docker daemon or socket hardening. Value: low.
7. **Add podman** for "build an image with fewer layers or a non-root user" tasks. Value: low.
8. Do not add cosign, helm repos, jq or tmux as exam tools. No evidence they exist on exam hosts.

## 5. What not to train

- OPA Gatekeeper and Kyverno (not in the curriculum, no 2025-2026 report).
- PodSecurityPolicy (removed from Kubernetes).
- Material older than Oct 2024: old weights (Cluster Setup 10%), AppArmor annotation as the only method, "TLS/mTLS" wording without Cilium.
- Deep Cilium (Hubble, Cluster Mesh, L7 policies, SPIRE mutual auth details). Keep Cilium to basic CiliumNetworkPolicy and one encryption check.
- Deep Istio (traffic routing, gateways, AuthorizationPolicy beyond basics).
- cosign signing flows. In scope only as an idea ("sign and validate artifacts"). No report of a cosign task.
- Trivy features beyond `trivy image` with severity filters and SBOM output formats.

## 6. Open points

- The exact CNI per exam cluster is not public. Check the killer.sh session: run `k -n kube-system get pods` on each cluster and note the CNI. That is our best proxy.
- After each new candidate report (2026), update tiers B and C.
