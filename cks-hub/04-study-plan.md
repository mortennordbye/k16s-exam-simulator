# CKS study plan (start 2026-11-21, exam target 2026-12-17)

Goal: pass CKS in one try, which also renews the CKA. Few sources, done well.

## Key dates

| Date | What |
|---|---|
| 2026-11-21 | Buy the exam (normal CKS, **not** "CKS-SINGLE", so you get 2 killer.sh sessions). Build the lab. |
| 2026-12-06 | killer.sh session A (timed 2 h, then 36 h to redo all tasks). |
| 2026-12-13 | killer.sh session B. |
| **2026-12-17** | **Exam, first try.** Book it in the first week. |
| 2026-12-18 to 2027-01-15 | Retake window if needed (free retake included). |
| 2027-01-30 | CKA expires. A CKS pass after 2026-06-18 resets the CKA expiry to the CKS expiry. |

I assumed about 90 min on weekdays and about 3 h on weekend days. Move the dates if that is wrong.

## Your lab (K16S, installed 2026-11-21)

Exam-like setup: Kubernetes v1.37.2, `controlplane` + `node01` + `node02`, remote Linux desktop with Firefox, 3 graded CKS mocks.
Run everything from this folder with `make`:

| Task | Command |
|---|---|
| See all commands | `make` |
| Today's plan row | `make today` |
| Start / stop the lab | `make up` / `make stop` |
| **Practise here: questions left, remote desktop right** | `make exam` |
| Remote desktop alone | `make desktop` |
| Root shell on the control plane | `make ssh`, then `ssh node01` |
| Start over from zero (about 6 min) | `make rebuild` |
| Free VM disk | `make clean` |

Keys in the desktop (same as the exam): use **Ctrl**, not Cmd. Terminal: Ctrl+Shift+C / Ctrl+Shift+V. Firefox inside the desktop: Ctrl+C / Ctrl+V. To bring text from your Mac in, use the clipboard panel in the noVNC side bar (left edge). In the real exam you cannot paste from your own machine at all, so practise copying inside the desktop.

Local patches in `repos/k16s-exam-simulator`: `local/lima.yaml` runs `apt-get update` at boot (the stock install failed on `gnupg2`). The Makefile calls `local/k16s-local` directly, which avoids the macOS bash bug in `install.sh`.

## Rules for each session

1. One topic. Do it on a real node, not in your head.
2. Learn the steps from `05-drills.md`, then do the task again from a blank terminal with only kubernetes.io open.
3. Time each drill. Write the time in the log at the end of this file.
4. Rebuild the lab when you break it (`make rebuild`, about 6 min). Do not lose time on repair.

## Sources (only these)

1. **killer.sh** (2 sessions, included). The best source.
2. **Killercoda CKS scenarios** (free): https://killercoda.com/killer-shell-cks
3. **K16S on your Mac** (installed, see "Your lab" below). Your lab for drills and 3 graded CKS mocks.
4. **ViktorUJ mocks** (AWS spot, `repos/cks`) only if you want more full mocks.
5. Kim Wuestkamp's free YouTube course: only the sections for your gaps, at 1.5x.

Skip: KodeKloud, long books, Cilium and Istio deep dives.

## Phase 1: your gaps first (node-level work, Tier 1 and 2)

Your profile (`01-profile.md`) shows strong supply chain, Falco and Linux skills. Your main gap is the kubeadm control plane. Talos and AKS hide it. So the plan starts there.

| Day | Date | Topic (session) | Practice |
|---|---|---|---|
| 1 | Sat 11-21 | Lab is built (K16S). Get to know it. Set up `vim` and aliases. Read the v1.37 curriculum PDF. Buy the exam by 12-01 at the latest. | `k get nodes` OK |
| 2 | Sun 11-22 | **Static pod workflow + audit logging.** Back up, edit, mount, wait, debug with `crictl` and `journalctl`. | Drill D1, D2. Killercoda "Auditing" |
| 3 | Mon 11-23 | **Secrets encryption at rest** + read a secret from etcd with `etcdctl`. | Drill D3 |
| 4 | Tue 11-24 | **ImagePolicyWebhook** + admission plugins + anonymous auth + NodeRestriction. | Drill D4. Killercoda "ImagePolicyWebhook" |
| 5 | Wed 11-25 | **AppArmor + seccomp** (load on the node where the pod runs). | Drill D5, D6 |
| 6 | Thu 11-26 | **kube-bench + kubelet hardening + binary verify** (`sha512sum`). | Drill D7. Apply every FAIL fix, not only find it |
| 7 | Fri 11-27 | Review: do D1 to D7 again from blank, 60 min max. | Log times |

## Phase 2: the rest of the curriculum (fast, you know most of it)

| Day | Date | Topic | Practice |
|---|---|---|---|
| 8 | Sat 11-28 | **NetworkPolicy** (plain k8s, not Cilium): default deny, allow DNS, block 169.254.169.254. **Ingress TLS.** | Drill D8. Killercoda NetworkPolicy scenarios |
| 9 | Sun 11-29 | **RBAC, ServiceAccounts, PSA labels, securityContext / immutability.** | Drill D9, D10 |
| 10 | Mon 11-30 | **RuntimeClass (gVisor runsc)** + Secrets usage. Light look: CiliumNetworkPolicy, Cilium encryption status, Istio PeerAuthentication STRICT. | Drill D11 |
| 11 | Tue 12-01 | **Supply chain:** Trivy CLI flags (no Trivy docs in the exam), `bom` SBOM, kubesec, KubeLinter, Dockerfile fixes. | Drill D12 |
| 12 | Wed 12-02 | **Falco** on the node: rules, output format, log file. **Investigate** with `crictl`, `/proc`. | Drill D13 |
| 13 | Thu 12-03 | **kubeadm upgrade** (CKA recap) + host footprint (`ss -tlpn`, `systemctl`, remove packages). | Drill D14 |
| 14 | Fri 12-04 | Rest or light review of your slowest 3 drills. | |

## Phase 3: mock exams and fixes

| Day | Date | Topic |
|---|---|---|
| 15 | Sat 12-05 | Full mock: K16S mock 1 (local). Use exam rules: 2 h, kubernetes.io only. |
| 16 | Sun 12-06 | **killer.sh session A.** 2 h timed. Then read all solutions. |
| 17 | Mon 12-07 | Inside the 36 h window: redo every task you missed in session A. |
| 18 to 20 | 12-08 to 12-10 | Fix the 3 weakest topics from session A. Killercoda only for these. |
| 21 | Fri 12-11 | Rest. |
| 22 | Sat 12-12 | Full mock: K16S mock 2 or one ViktorUJ mock (AWS, destroy right after). |
| 23 | Sun 12-13 | **killer.sh session B.** 2 h timed. Then redo misses. |
| 24 to 25 | 12-14 to 12-15 | Redo misses. Practise doc search speed (find the audit, encryption, AppArmor, seccomp, RuntimeClass pages in under 20 s). |
| 26 | Wed 12-16 | Light only. Run the PSI system check. Test `\|`, `{`, `~`, `$` with your keyboard layout. Turn off Bluetooth on the Mac. |
| 27 | **Thu 12-17** | **Exam.** |

## Exam day tactics (short)

- Read all tasks first (5 min). Do the easy ones first. Flag and skip anything over 8 min.
- Always run the `ssh` command from the task. Go back to `base` after.
- `sudo -i` once per node.
- Back up a manifest to `/root/` (outside `/etc/kubernetes/manifests/`) before you edit it.
- While the apiserver restarts, read the next task.
- Verify every change. Partial work gives points, so never leave a task blank.

## Pass check before the exam

You are ready when all of these are true:
- killer.sh session B score is 60% or more, and you understand every miss.
- You can do D1 to D7 from blank in under 8 min each.
- You can find each allowed doc page you need in under 20 s.

## Time log

| Date | Drill / mock | Time / score | Notes |
|---|---|---|---|
| | | | |
