# CKS exam facts (checked 2026-11-21)

Scope: official facts first, then what recent candidates report. Check the official pages again in the week you book. The Linux Foundation (LF) changes the Kubernetes version and the docs list without much notice.

## 1. Key facts at a glance

| Item | Value | Source |
|---|---|---|
| Format | Online, proctored, hands-on tasks in a remote Linux desktop. No multiple choice. | [LF CKS page](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) |
| Tasks | 15 to 20 tasks | [CKS Important Instructions](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks) |
| Duration | 2 hours | same |
| Kubernetes version | v1.37 ("The CKS environment is currently running Kubernetes v1.37.") | same, and [LF FAQ](https://docs.linuxfoundation.org/tc-docs/certification/faq-cka-ckad-cks) |
| Passing score | 67% (CKA and CKAD use 66%) | [LF FAQ CKA/CKAD/CKS](https://docs.linuxfoundation.org/tc-docs/certification/faq-cka-ckad-cks) |
| Results | By email, about 24 hours after the exam | [Important Instructions](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks) |
| Prerequisite | You must have taken and passed CKA before you try CKS. | [LF FAQ](https://docs.linuxfoundation.org/tc-docs/certification/faq-cka-ckad-cks) |
| Price | USD 445 exam only. Bundles: 625 with THRIVE-ONE, 645 with LFS260. | [LF CKS page](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) |
| Retake | 1 free retake, only after a "No Pass". No wait period, but scoring takes up to 24 h and booking needs 24 h lead time. Retake must be done within 12 months of purchase. | [LF Certification FAQ](https://training.linuxfoundation.org/about/faqs/certification-faq/) |
| Exam eligibility | 12 months from purchase. LF advises to book the first attempt at least 2 weeks before expiry, to leave room for a retake. | same |
| Reschedule/cancel | Allowed more than 24 h before start. Inside 24 h: take it or lose it. | same |
| Simulator | 2 killer.sh sessions. Each gives 36 hours of access from activation, with graded results. Not included in "CKS-SINGLE" registrations. | [LF FAQ](https://docs.linuxfoundation.org/tc-docs/certification/faq-cka-ckad-cks) |
| Cert validity | 2 years | same |

## 2. Does passing CKS renew CKA? Yes (since 2026-06-18)

The exact rule, from the [CARE Program page](https://training.linuxfoundation.org/care-program/) and the [LF blog post](https://training.linuxfoundation.org/blog/expanding-care-passing-cks-can-now-extend-your-cka-certification/) ([CNCF copy](https://www.cncf.io/blog/2026/06/17/expanding-care-passing-cks-can-now-extend-your-cka-certification/)):

- You must have earned CKA before. It can be current or expired ("non-current").
- You must earn or recertify CKS on or after **June 18, 2026**. "Renewals cannot be applied retroactively to certifications earned before that date."
- Then CKA becomes current again, and its expiry date is set to match the new CKS expiry date.
- One CKS pass can renew up to three certs: KCSA (rule since 2026-01-01), CKA and KCNA.
- CARE cannot grant a cert you never held.
- Allow a few business days for the renewal to show.
- If your certs sit in different LF accounts, contact LF Support to link them.

What this means for you: a CKS pass in Dec 2026 makes CKA valid to the same date as the new CKS (about Dec 2028). You get no separate CKA exam.

Open point: the CNCF post does not say what happens if your CKA expiry is later than the new CKS expiry. Since your CKA is close to expiry, this does not matter for you.

Prerequisite note: LF says you must have "taken and passed" CKA. LF does not say the CKA must be active at booking time. The CARE text says an expired CKA can be reinstated. To be safe, buy and book CKS while the CKA is still active.

## 3. Curriculum and domain weights

Current file: `CKS_Curriculum v1.37.pdf` in [github.com/cncf/curriculum](https://github.com/cncf/curriculum). The LF course page also still links a PDF labelled v1.34. The domain text is the same.

| Weight | Domain | Competencies (official wording, short) |
|---|---|---|
| 15% | Cluster Setup | NetworkPolicy to restrict cluster level access. CIS benchmark review of etcd, kubelet, kubedns, kube-apiserver. Ingress with TLS. Protect node metadata and endpoints. Verify platform binaries before deploy. |
| 15% | Cluster Hardening | RBAC to minimize exposure. Service accounts: disable defaults, minimize permissions. Restrict access to the Kubernetes API. Upgrade Kubernetes. |
| 10% | System Hardening | Minimize host OS footprint. Least-privilege IAM. Minimize external network access. Kernel hardening: AppArmor, seccomp. |
| 20% | Minimize Microservice Vulnerabilities | Pod Security Standards. Manage Secrets. Isolation (multi-tenancy, sandboxed containers). Pod-to-pod encryption (Cilium, Istio). |
| 20% | Supply Chain Security | Minimize base image. Understand supply chain (SBOM, CI/CD, artifact repos). Secure it (permitted registries, sign and validate artifacts). Static analysis (Kubesec, KubeLinter). |
| 20% | Monitoring, Logging and Runtime Security | Behavioral analytics. Detect threats. Investigate attack phases and bad actors. Container immutability at runtime. Audit logs. |

Sources: [LF CKS page](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/), CKS_Curriculum v1.37.pdf (text extracted locally).

Three domains of 20% give 60% of the score. Put most time there.

### Curriculum change history

- **Oct 15, 2024** (first planned Sep 12, then "no earlier than Oct 10"): the last structural change. Cluster Setup went 10% to 15%, System Hardening went 15% to 10%. Added: Cilium for pod-to-pod encryption (old text said TLS/mTLS), SBOM, Kubesec and KubeLinter, Pod Security Standards. Text for gVisor/Kata and for registry whitelisting got more general. Sources: [techiescamp](https://blog.techiescamp.com/cks-exam-update/), [rx-m](https://rx-m.com/upcoming-changes-to-the-cks-exam-what-you-need-to-know/), [KodeKloud](https://kodekloud.com/blog/cks-exam-updates-2024-your-complete-guide-to-certification-with-kodekloud/).
- **2025 to 2026:** no domain change. Only the Kubernetes version moves (v1.34, v1.35, v1.36, now v1.37). LF moves to a new minor release about 4 to 8 weeks after it ships ([nhimg guide](https://nhimg.org/certified-kubernetes-security-specialist-guide)).
- Trap in old material: the cncf/curriculum README and many blogs still show the old 10/15 split for Cluster Setup and System Hardening. The PDF and LF page show 15/10 ([nhimg guide](https://nhimg.org/certified-kubernetes-security-specialist-guide)).
- Note: "gVisor" and "Kata" names are gone from the text, but "sandboxed containers" stays. RuntimeClass tasks still appear in practice material.

## 4. Allowed resources in the exam

Official list ([LF Resources Allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed)):

- kubernetes.io/docs (its search is OK, but do not open external results)
- kubernetes.io/blog
- falco.org/docs
- kubernetes-sigs.github.io/bom/cli-reference/
- etcd.io/docs
- kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/
- docs.cilium.io
- istio.io/latest/docs
- Task links in the "Quick Reference" box of each task
- Docs installed by the distro under /usr/share, man pages, and distro packages (you may install packages)

**Not on the official list now:** Trivy docs, AppArmor wiki, github.com/kubernetes. Older guides (for example [devopscube](https://devopscube.com/cks-exam-guide-tips/), [KodeKloud](https://kodekloud.com/blog/certified-kubernetes-security-specialist-cks-exam-verification-guide/)) still list Trivy and AppArmor. Do not count on them. Learn `trivy image`, `trivy --help`, and the AppArmor commands by heart. The Kubernetes docs have a full AppArmor page and a seccomp page.

## 5. Exam environment (PSI remote desktop)

From [CKS Important Instructions](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks) and [ExamUI for performance-based exams](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2/exam-user-interface/examui-performance-based-exams):

- You work inside a remote Linux desktop (XFCE) with a terminal, Firefox for docs, and VSCodium (no extensions).
- Each task names its host. Run `ssh <nodename>`. Go back to the host `base` after each task. Nested SSH does not work.
- Do not reboot `base`. It does not reset your environment.
- Root: `sudo -i`, or `sudo <cmd>`.
- On the SSH hosts only: `kubectl` with alias `k` and bash completion, `yq`, `curl`, `wget`, `man`. The base node does not have these tools.
- Copy/paste in the terminal: **Ctrl+Shift+C / Ctrl+Shift+V** (or right-click). In Firefox and other apps: Ctrl+C / Ctrl+V.
- Ctrl+W closes the browser tab. Use **Ctrl+Alt+W** to delete a word in the terminal.
- The INSERT key is blocked. In vi, use `i` and Esc.
- Each task has click-to-copy text (names, paths). Use it to avoid typos ([sakisv, 2025](https://www.sakisv.net/2025/04/zero-to-cks-in-4-months/)).
- The timer starts after the UI tour ends. Alerts at 30, 15 and 5 minutes. Pause and lost connection do not stop the timer.
- "Installing some exam services may require modifying system security policies" (official note). Expect AppArmor or similar to block something by design.
- Some international keyboards mistype special characters. Use a US layout, or the on-screen keyboard. (Norwegian keyboard users: test `|`, `{`, `~` and `$` in the killer.sh desktop first.)
- Older 2025 reports describe kubectl contexts instead of SSH per task ([sakisv](https://www.sakisv.net/2025/04/zero-to-cks-in-4-months/)). The current official text says SSH per task. Read the infobox on each task and do exactly what it says.

Check-in and PSI quirks from candidates:

- Check in early. Room scan and check-in can take 10 minutes or more ([schnatterer](https://github.com/schnatterer/cks-short-tips), [bargenqua.st](https://bargenqua.st/posts/cks-cka-2025/)).
- One external monitor only, or the laptop screen only. A second monitor caused a new check-in ([schnatterer](https://github.com/schnatterer/cks-short-tips)).
- On macOS, PSI blocked a `SideCarRelay` process. The fix was to turn off Bluetooth and use wired keyboard and mouse ([bargenqua.st, 2025](https://bargenqua.st/posts/cks-cka-2025/)).
- Do not press mouse thumb (back) buttons. Keep eyes on the screen. Use a stable, wired network ([schnatterer](https://github.com/schnatterer/cks-short-tips), [bargenqua.st](https://bargenqua.st/posts/cks-cka-2025/)).

## 6. killer.sh simulator

- 2 sessions, 36 h each, graded. The first 2 hours act as a timed exam. After that you keep the environment and solutions until the 36 h end ([LF FAQ](https://docs.linuxfoundation.org/tc-docs/certification/faq-cka-ckad-cks), [sakisv](https://www.sakisv.net/2025/04/zero-to-cks-in-4-months/)).
- About 23 tasks versus about 16 in the real exam. One 2025 candidate found the CKS simulator about as hard as the real exam (for CKA it was harder). Score example: 33/85 first run, 63/85 second run, then a pass ([sakisv](https://www.sakisv.net/2025/04/zero-to-cks-in-4-months/)).
- killer.sh does not map its score to an exam score ([killer.sh FAQ](https://killer.sh/faq)).
- Common plan: session 1 about 2 weeks before the exam (find gaps), session 2 a few days before (speed). Redo all 23 tasks from the solutions inside the 36 h.
- Free extra practice: [Killercoda CKS scenarios](https://killercoda.com/killer-shell-cks) cover the newer topics (SBOM, Cilium, PSS) better than the old free course ([sakisv](https://www.sakisv.net/2025/04/zero-to-cks-in-4-months/)).

## 7. Highest-yield topics

Ranked by how often they show up in recent candidate reports, killer.sh, and the curriculum. This ranking is a synthesis, not an official list. Sources: [sakisv 2025](https://www.sakisv.net/2025/04/zero-to-cks-in-4-months/), [bargenqua.st 2025](https://bargenqua.st/posts/cks-cka-2025/), [Medium: CKS 2026](https://medium.com/@gurbanvaliev1/cks-2026-my-path-to-the-kubernetes-security-certification-fe70d49cbc5c), [Medium: 88/100 in 2025](https://medium.com/@leehosanganson/journey-to-kubestronaut-in-2025-how-did-i-score-88-100-in-cks-ccb897735ed8), [sailor.sh mistakes](https://sailor.sh/blog/cks-exam-common-mistakes-to-avoid/), [devopscube](https://devopscube.com/cks-exam-guide-tips/), [DynamoDevOps notes](https://medium.com/@DynamoDevOps/think-less-execute-more-notes-i-wish-i-had-before-the-cks-exam-cbe04430446c).

### Tier 1: expect it (nearly every report)

| Topic | What the task usually wants |
|---|---|
| NetworkPolicy | Default-deny, then allow by pod/namespace label. Keep DNS (UDP/TCP 53) in egress. Block 169.254.169.254 metadata. |
| kube-apiserver hardening | Edit `/etc/kubernetes/manifests/kube-apiserver.yaml`: anonymous-auth, authorization-mode, admission plugins, NodeRestriction, insecure flags. Wait for restart. |
| Audit logging | Write an audit Policy, add `--audit-policy-file`, `--audit-log-path`, maxage/maxbackup/maxsize, plus hostPath volume mounts. First matching rule wins. |
| kube-bench / CIS | Run kube-bench, fix the named FAIL items on apiserver, kubelet (`/var/lib/kubelet/config.yaml`), etcd. Apply the fix, not only find it. |
| Falco | Find which pod does X, change a rule's output format, write to a log file. Rules in `/etc/falco/`. Docs are allowed. |
| AppArmor | Load a profile with `apparmor_parser` on the node, check `aa-status`, set `securityContext.appArmorProfile` (field form, GA since v1.30). |
| Trivy | Scan images used by pods, delete pods with HIGH/CRITICAL CVEs. Docs not allowed, so know the flags. |
| RBAC and ServiceAccounts | Least-privilege Role/RoleBinding, new SA, `automountServiceAccountToken: false` on SA or pod. |
| Pod Security Admission | Namespace labels `pod-security.kubernetes.io/enforce: restricted` or `baseline`, then fix the pods that fail. |
| securityContext / immutability | `readOnlyRootFilesystem`, runAsNonRoot, drop capabilities, no privileged, emptyDir for writable paths. |

### Tier 2: often

| Topic | Note |
|---|---|
| Secrets encryption at rest | EncryptionConfiguration (aescbc or secretbox), `--encryption-provider-config`, then re-write all secrets. Read a secret from etcd with `etcdctl`. |
| RuntimeClass / gVisor | Create RuntimeClass with handler `runsc`, set `runtimeClassName` on pods. |
| ImagePolicyWebhook | AdmissionConfiguration file, kubeconfig for the webhook, `defaultAllow: false`. A 2026 candidate broke the apiserver by not setting the `server` field in the webhook kubeconfig. |
| seccomp | `RuntimeDefault` or a Localhost profile under `/var/lib/kubelet/seccomp/`. |
| Ingress with TLS | TLS secret, `tls:` block in Ingress, maybe redirect annotation (ingress-nginx docs allowed). |
| Cluster upgrade | kubeadm upgrade of control plane and a worker. Same as CKA. |
| SBOM with bom / Trivy | `bom generate` SPDX of an image, or `trivy image --format spdx-json`/cyclonedx. Find an image with a vulnerable package. |
| Static analysis | Kubesec or KubeLinter on a manifest, fix the findings. Also find bad lines in a Dockerfile. |
| Verify binaries | `sha512sum` of kubelet/kubectl against the release hash. |

### Tier 3: possible, lower return per hour

- Cilium: CiliumNetworkPolicy, and WireGuard or IPsec pod-to-pod encryption, or mutual auth. One 2025 candidate studied it a lot and got no Cilium task ([88/100 report](https://medium.com/@leehosanganson/journey-to-kubestronaut-in-2025-how-did-i-score-88-100-in-cks-ccb897735ed8)). Another saw Cilium network policy ([bargenqua.st](https://bargenqua.st/posts/cks-cka-2025/)). Learn the basic CiliumNetworkPolicy and the encryption check commands. Docs are allowed.
- Istio mTLS (PeerAuthentication STRICT). Docs allowed.
- Host footprint: find and stop a service, remove a package, close a port (`ss -tlpn`, `systemctl`).
- Investigate a runtime attack with `crictl`, `/proc`, and strace (the 88/100 report saw no strace task).
- Restrict kubelet: `anonymous.enabled: false`, `authorization.mode: Webhook`.

## 8. Time savers and traps from recent candidates

Time savers:

1. Read all tasks fast at the start (about 5 min), flag the hard ones, do the easy ones first. Tasks are not in order of difficulty ([sakisv](https://www.sakisv.net/2025/04/zero-to-cks-in-4-months/), [bargenqua.st](https://bargenqua.st/posts/cks-cka-2025/)).
2. Skip a task that eats time. Come back at the end. A candidate failed at 55%, then passed with 90% three days later with this one change ([Medium: CKS 2026](https://medium.com/@gurbanvaliev1/cks-2026-my-path-to-the-kubernetes-security-certification-fe70d49cbc5c)).
3. While the apiserver restarts, start the next task, then come back and check ([bargenqua.st](https://bargenqua.st/posts/cks-cka-2025/)).
4. Copy YAML from the docs. Use `--dry-run=client -o yaml` and `kubectl explain`. Use click-to-copy for names.
5. Use `sudo -i` once per node, not `sudo` on every line ([schnatterer](https://github.com/schnatterer/cks-short-tips)).
6. Partial work earns points. Never leave a task blank.
7. Learn the bash shortcuts: Ctrl+R (history), Ctrl+Alt+W (delete word).

Traps:

1. Wrong host or context. Always run the SSH or context command from the task, even if you think you are already there.
2. A broken kube-apiserver manifest. Always `cp` the manifest to a backup **outside** `/etc/kubernetes/manifests/` (a copy inside that folder also runs as a static pod). Check with `crictl ps` and `journalctl -u kubelet` or `/var/log/pods/`.
3. New apiserver files (audit policy, encryption config, admission config) need a hostPath volume and volumeMount, or the apiserver does not start.
4. Editing the manifest again before the pod has restarted.
5. Audit policy: a catch-all rule above a specific rule hides it.
6. NetworkPolicy egress default-deny that blocks DNS.
7. AppArmor profile not loaded on the node where the pod runs.
8. kube-bench: you find the FAIL but do not apply the fix.
9. Kubelet config change without `systemctl restart kubelet`.
10. Results written to the wrong file or wrong host. Output files can be on `base` or on a node; read the path.
11. No verification. Check every change with `k get`, `k describe`, `k auth can-i`, or logs.
12. Study material older than Oct 2024 (PodSecurityPolicy, old weights, old AppArmor annotation as the only method).

## 9. Booking advice for a CKA renewal

- Buy the exam now while CKA is active. The 12-month eligibility gives room for the free retake.
- Book the first attempt with at least 1 to 2 weeks of margin before the CKA expiry date, so a retake can still happen in time. Results take up to 24 h, and the CARE renewal takes "a few business days".
- Do not buy a "CKS-SINGLE" registration. It has no killer.sh sessions.
