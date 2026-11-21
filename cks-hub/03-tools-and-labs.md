# CKS tools and labs (checked 2026-11-21)

Goal: high value per hour. Few sources, done well. Not a big pile of material.

## Exam facts that drive the choice

- Exam runs on Kubernetes v1.37. Duration is 2 hours. One retake is included. Price is USD 445. The certificate is valid for 2 years. You must hold a CKA first. Source: https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/
- Domain weights: Minimize Microservice Vulnerabilities 20%, Supply Chain Security 20%, Monitoring/Logging/Runtime Security 20%, Cluster Setup 15%, Cluster Hardening 15%, System Hardening 10%. Same source.
- Official curriculum PDF: "CKS_Curriculum v1.37.pdf" in https://github.com/cncf/curriculum (pushed 2026-11-12).
- killer.sh: the exam purchase includes 2 sessions (CKS-A and CKS-B, different questions, 17 + 17). Each session is open for 36 hours from activation. The simulator runs v1.37. An extra session costs USD 9.99 if you bought or got the simulator in the last 12 months. Source: https://killer.sh/faq

## Ranked table (value per hour)

| Rank | Resource | Cost | Hours | Why it ranks here | Notes |
|---|---|---|---|---|---|
| 1 | killer.sh CKS simulator, 2 included sessions (https://killer.sh/cks) | Included with exam | 2 x 2 h timed + 2 x 2 h review | Closest to the real exam. Harder than the exam. Solutions are the best study text you will get. | Do session A at about day 10, session B about 4 days before the exam. Use the 36 h window to redo every wrong task. |
| 2 | Killercoda CKS scenarios (https://killercoda.com/cks) | Free (PLUS only for the exam remote desktop) | 10 to 15 h | Short, focused, browser based, real node access. Covers NetworkPolicy, RBAC, PSA, AppArmor, seccomp, image policy, Falco, audit logs, kube-bench, Trivy. | Map of course topic to scenario: https://github.com/killer-sh/cks-course-environment/blob/master/Scenarios.md |
| 3 | Kim Wuestkamp CKS full course, free on YouTube (https://youtu.be/d9xfB5qaOfg) with repo https://github.com/killer-sh/cks-course-environment | Free (Udemy version is paid) | About 11 h video, watch at 1.5x on weak topics only | Same author as killer.sh. Each section ends in a Killercoda scenario. Repo has `install_master.sh` / `install_worker.sh` for kubeadm v1.37.1, amd64 and arm64. | Repo has no license file. Read and run scripts in your own VMs. Do not redistribute. Udemy edition context: https://wuestkamp.medium.com/k8s-cks-course-with-browser-challenges-a3fbba781959 |
| 4 | ViktorUJ/cks mock exams (https://github.com/ViktorUJ/cks) | Free code, AWS spot cost (small, pay per hour) | 2 h per mock | Best free full mock exams with auto checks. Runs real kubeadm clusters on AWS EC2 spot via Terraform/Terragrunt (`make run_cks_mock`). | Apache-2.0, 1687 stars, pushed 2026-10-27. Needs an AWS account. Destroy right after use. Write-up: https://medium.com/@viktoruj/the-path-to-passing-the-cks-exam-from-challenges-to-creating-a-simulator-df39aeb5d392 |
| 5 | K16S exam simulator (https://github.com/immanuwell/k16s-exam-simulator) | Free for personal use | 2 h per mock, 3 CKS mocks | Real kubeadm cluster on your Mac in Lima (`install.sh --laptop`). Per task setup and grading. Covers AppArmor, seccomp, kube-bench, apiserver and kubelet hardening. | PolyForm Noncommercial 1.0.0. Personal study is OK. 237 stars, pushed 2026-09-08. Needs 16 GB+ RAM. New project: test one mock before you trust it. |
| 6 | KodeKloud CKS course + Ultimate CKS Mock Exam Series (https://kodekloud.com/courses/certified-kubernetes-security-specialist-cks, https://kodekloud.com/courses/ultimate-certified-kubernetes-security-specialist-cks-mock-exam-series) | Paid subscription | Course 15 h, 3 + 3 mocks | Good guided labs if you want a structured course. | Labs listed at v1.33 upgrade (May 2025). 2026 forum reports of broken checkers in mocks (https://kodekloud.com/community/c/cks/72). Lower value per hour for an experienced CKA. Skip unless you already pay for it. |
| 7 | sailor-sh/CK-X (https://github.com/sailor-sh/CK-X) | Free for personal use | 2 h per mock | Docker based timed simulator with remote desktop UI. | BSL 1.1, personal/educational use allowed. 1325 stars, pushed 2026-10-21. Uses kind, so node-level CKS tasks are weak. Free tier has only 1 to 2 CKS mocks (vendor claim: https://sailor.sh/blog/how-to-practice-cks-for-free/). |
| 8 | walidshaari/Certified-Kubernetes-Security-Specialist (https://github.com/walidshaari/Certified-Kubernetes-Security-Specialist) | Free | 1 h to scan | Curated links per domain. Good for the allowed-docs bookmarks and tool docs. | CC-BY-SA-4.0, 2135 stars, pushed 2026-03-14. Reading list only, no labs. |
| 9 | techiescamp/cks-certification-guide (https://github.com/techiescamp/cks-certification-guide) | Free | 1 to 2 h | Up to date study guide and command notes. | License "Other" (check before reuse). 119 stars, pushed 2026-11-13. |
| 10 | moabukar/CKS-Exercises (https://github.com/moabukar/CKS-Exercises-Certified-Kubernetes-Security-Specialist) | Free | 3 to 5 h | Exercises per domain. | Apache-2.0, 295 stars, last push 2022-08-23. Stale (pre PSA, old Falco/Trivy flags). Use only for extra drills. |
| 11 | bmuschko/cks-crash-course (https://github.com/bmuschko/cks-crash-course) | Free to read | 3 to 5 h | Clean exercises with solutions by an O'Reilly author. | No license file. 183 stars, pushed 2025-11-18. Read online, do not redistribute. |

Not recommended for this short plan: stackrox/Kubernetes_Security_Specialist_Study_Guide (MIT, last push 2021-01-04, stale), abdennour/certified-kubernetes-security-specialist (no license, 2023), echoboomer/k8s-cks-notes (no license, 2022), kodekloudhub/certified-kubernetes-security-specialist-cks-course (no license, notes only, 2025-05-28).

### Lab setup repos (checked)

| Repo | License | Stars | Last push | Use |
|---|---|---|---|---|
| https://github.com/lima-vm/lima (template `k8s.yaml`) | Apache-2.0 | 22422 | 2026-11-19 | Official kubeadm template, multi-node over `lima:user-v2`. |
| https://github.com/canonical/multipass | GPL-3.0 | 9413 | 2026-11-21 | Ubuntu VMs on Apple Silicon. |
| https://github.com/aapit/ansible-k8s-cks | MIT | 0 | 2026-10-25 | Multipass + Ansible CKS cluster, Cilium, Falco (modern eBPF), Gatekeeper, Kyverno, arm64. Small project: read it before you run it. |
| https://github.com/techiescamp/vagrant-kubeadm-kubernetes | GPL-3.0 | 859 | 2026-11-04 | Vagrant kubeadm lab (VirtualBox, mainly x86). |
| https://github.com/techiescamp/vagrant-kubeadm-mac-silicon | CC0-1.0 | 61 | 2026-11-04 | Vagrant + VMware Fusion on Apple Silicon. |
| https://github.com/kubernetes-sigs/kind | Apache-2.0 | 15634 | 2026-11-19 | Fast pod-level drills only. |
| https://github.com/mmumshad/kubernetes-the-hard-way | Apache-2.0 | 5215 | 2025-11-17 | Deep cluster internals. Not needed for this plan. |

Repos that do not exist (checked with gh): `killercoda/scenarios-cks`, `kodekloudhub/kubernetes-security-cks`, `sandervanvugt/cks`, `module0/cks`.

## Clone list

Only repos with an open or free personal-use license. Clone into `~/Documents/CKS/repos`.

```bash
mkdir -p ~/Documents/CKS/repos && cd ~/Documents/CKS/repos

# Mock exams
git clone https://github.com/ViktorUJ/cks.git                                  # Apache-2.0, AWS mocks
git clone https://github.com/immanuwell/k16s-exam-simulator.git                # PolyForm Noncommercial, local Lima mocks

# Reading list and drills
git clone https://github.com/walidshaari/Certified-Kubernetes-Security-Specialist.git   # CC-BY-SA-4.0
git clone https://github.com/moabukar/CKS-Exercises-Certified-Kubernetes-Security-Specialist.git  # Apache-2.0, old

# Local lab
git clone https://github.com/aapit/ansible-k8s-cks.git                         # MIT, Multipass CKS lab
```

Optional (no license file, so use for private study only, do not share copies):

```bash
git clone https://github.com/killer-sh/cks-course-environment.git   # course scripts install_master.sh / install_worker.sh
```

## Local lab recipe (macOS, Apple Silicon)

Why not only kind: kind nodes are containers. You get no real systemd, no real kubelet config on a node, no AppArmor profile load into a node kernel, and Falco drivers do not work well. The exam asks you to edit `/etc/kubernetes/manifests/kube-apiserver.yaml`, kubelet config, audit policy, AppArmor profiles with `apparmor_parser`, and Falco rules on a node. Use kubeadm in real VMs for this. Use kind only for fast NetworkPolicy, RBAC and PSA drills. Sources: https://github.com/immanuwell/k16s-exam-simulator, https://sailor.sh/blog/kubernetes-practice-lab-cncf-exams/

Recipe A: Multipass + killer.sh course scripts (closest to the course, v1.37.1, arm64 support).

```bash
brew install --cask multipass
multipass launch 24.04 --name cks-master --cpus 2 --memory 4G --disk 30G
multipass launch 24.04 --name cks-worker --cpus 2 --memory 4G --disk 30G

# On the master
multipass shell cks-master
sudo -i
bash <(curl -s https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/cluster-setup/latest/install_master.sh)
# The script prints a "kubeadm join ..." command at the end. Copy it.

# On the worker
multipass shell cks-worker
sudo -i
bash <(curl -s https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/cluster-setup/latest/install_worker.sh)
# Then run the join command from the master.

# Snapshot so you can reset after you break things
multipass stop cks-master cks-worker
multipass snapshot cks-master --name clean
multipass snapshot cks-worker --name clean
multipass start cks-master cks-worker
# Reset: multipass restore cks-master.clean (VM must be stopped)
```

Script source and README: https://github.com/killer-sh/cks-course-environment. Read the script before you run it.

Notes:
- Multipass uses 192.168.64.0/24 by default. Keep the pod CIDR away from 192.168.0.0/16 (for example 10.244.0.0/16). VM IPs can change after a host reboot, which can break the cluster. Source: https://github.com/gwo-oj/kubeadm-lab
- Ubuntu 24.04 has AppArmor on by default. Check with `aa-status` on the worker.
- Install Falco on the worker with the modern eBPF driver (arm64 works). Example: https://github.com/aapit/ansible-k8s-cks
- Add tools as you study: `trivy`, `kube-bench` (run as a Job), `bom`/`kubesec` if the curriculum lists them.

Recipe B: Lima only (no extra app).

```bash
brew install lima
limactl start --name k8s --network lima:user-v2 template:k8s
limactl shell k8s sudo kubeadm token create --print-join-command
limactl start --name k8s-1 --network lima:user-v2 template:k8s \
  --param url="https://<ADDRESS>" --param token="<TOKEN>" \
  --param discoveryTokenCaCertHash="<HASH>"
```

Source: https://github.com/lima-vm/lima/blob/master/templates/k8s.yaml

Recipe C: zero setup. Run `bash install.sh --laptop` in the K16S repo. It builds a Lima VM with a kubeadm cluster and serves graded mock tasks on http://localhost:8080/. Source: https://github.com/immanuwell/k16s-exam-simulator

Resources: 2 VMs with 2 vCPU / 4 GB each is enough. K16S asks for 16 GB+ host RAM.

## Suggested use in a 20 to 30 day plan

1. Days 1 to 3: build Recipe A, take a snapshot. Read the v1.37 curriculum PDF.
2. Days 3 to 15: one domain per 1 to 2 days. Watch only the matching Kim Wuestkamp sections, then do the matching Killercoda scenarios. Repeat node tasks in your own lab.
3. About day 10: killer.sh session A. Redo every wrong task in the 36 h window.
4. Days 11 to 20: K16S mocks locally, or 1 to 2 ViktorUJ mocks on AWS. Drill weak domains on Killercoda.
5. About 4 days before the exam: killer.sh session B. Then only redo misses and practise docs navigation speed.
