# Lab setup and decisions (2026-11-21)

How the practice lab is built, why, and how to rebuild it. Read this before you change the lab.

## Decisions

| Decision | Why |
|---|---|
| Lab = **K16S** (`repos/k16s-exam-simulator`), laptop mode in a Lima VM | Real kubeadm cluster on the Mac. Graded CKS mocks. No cloud cost. |
| No Multipass lab | K16S covers it. One lab only. |
| Kubernetes **v1.37** | Same as the exam (K16S default is 1.33). |
| Profile **cks**, **2 workers** (`node01`, `node02`) | CKS mocks. K16S docs and tasks expect 2 workers. |
| **Desktop on** | The exam is a remote Linux desktop. Only practise there. |
| VM: 4 CPU, 8 GB RAM, **40 GB disk** | 30 GB failed the 20 GB free check after build caches. |
| **Second cluster `cilium-cp`**: VM `k16s-cilium`, 2 CPU, 4 GB RAM, 15 GB disk, one kubeadm node, Kubernetes **v1.36**, **Cilium 1.20.5** with WireGuard | The exam has more than one cluster and at least one with Cilium. v1.36 so the kubeadm upgrade task can go to v1.37. One node is enough for CiliumNetworkPolicy and the encryption check (WireGuard shows 0 peers). Cilium 1.20 is tested by Cilium up to Kubernetes 1.36; our tasks also pass on 1.37. |
| VM to VM network: **Lima user-v2** on both VMs | Works on vz (tested): one NIC on 192.168.104.0/24, VMs reach each other. Lima keeps the IP per MAC address, so it stays the same after stop and start. |
| **Host `base` = the main VM** (no second base VM) | A base VM costs RAM for nothing. The terminal opens as candidate on "base" (no kubectl, no `k`). `ssh controlplane` logs in to the same VM over ssh, then kubectl works. |
| candidate gets full sudo | `sudo -i` works on the task hosts, like the exam. Side effect: sudo works on base too. |
| **`make exam` is the only place to practise** | Questions left, remote desktop right, like the real exam. |
| Firefox on the Mac | The exam desktop uses Firefox for docs. |
| Exam bought later | Buy by 2026-12-01 so killer.sh A (12-06) and B (12-13) still fit. Exam target 2026-12-17. |

## The fork

The lab runs from your fork: https://github.com/mortennordbye/k16s-exam-simulator (branch `main`), cloned at `repos/k16s-exam-simulator`. Remotes: `origin` = your fork, `upstream` = immanuwell/k16s-exam-simulator. All changes are commits there (no patch files).

What the fork adds:

1. Lab: `apt-get update` at boot, macOS bash 3.2 fix in `install.sh`, Docker Hub through `mirror.gcr.io` (no rate limit), CKS tool profile (trivy, kube-bench, bom, kubesec, kube-linter, Falco, gVisor).
2. Exam UI: desktop first (full noVNC, remote resize), click-to-copy, divider, Guide button with full manifests, windows maximized.
3. **Real exam mode**: tasks set up at start, no hints, guide or checks, weight in %, flag for review, graded after End Exam, PASS/FAIL against 67%.
4. **Partial scoring**: points = weight x correct items / items. Only items the task asks for count (measured 20 s after setup). Breaking something that was correct (a guard) costs points.
5. **Tasks**: 19 new CKS v1.37 tasks (drill "New topics") and 3 mock exams (Mock 1 to 3, 15 to 17 tasks, 98 points each). Reference solutions in `dev/solutions/`, test log in `dev/TESTING.md`.
6. **Exam layout** (plan 03): second cluster `cilium-cp` with Cilium, exam host flow (base, `ssh <host>`), kubeadm upgrade task, Cilium tasks, node-level tasks only on the controlplane VM.

## Layout

```
Mac
 ├─ VM k16s (4 CPU, 8 GB)          main cluster, Calico, v1.37
 │   base       = desktop terminal and web terminal, user candidate, no kubectl
 │   ssh controlplane  -> same VM over ssh: kubectl, k, completion, yq, sudo -i
 │   ssh node01 / ssh node02  -> workers (Incus LXC, root)
 │   ssh cilium-cp     -> second cluster
 └─ VM k16s-cilium (2 CPU, 4 GB)    host cilium-cp, second cluster "cilium", Cilium + WireGuard, v1.36
```

Every task shows its host: "Solve this task on: ssh controlplane" or "ssh cilium-cp". Do the task there, then `exit` to base.

| Task host | Tasks |
|---|---|
| `ssh cilium-cp` | CiliumNetworkPolicy (b18, Mock 3), Cilium WireGuard encryption (b19, Mock 1), kubeadm upgrade (b17, Mock 2) |
| `ssh controlplane` | All other tasks. AppArmor, seccomp, Falco and gVisor pods run on node `controlplane` (VM kernel), never on an LXC worker. |

Setup and check scripts run as root on the controlplane and reach the second cluster with `ssh cilium-cp ...` (keys and `/etc/hosts` set by `k16s-local`).

Commands:

- `make ssh-cilium`: root shell on cilium-cp from the Mac.
- `make rebuild-cilium`: build only cilium-cp again at v1.36 (about 3 min). Needed to repeat the upgrade task: after an upgrade the cluster stays at v1.37, and a setup cannot go back in 120 s. On a repeat the setup says so, and only the "save nodes.txt" item gives points.
- `make stop` / `make up` / `make rebuild` / `make destroy` act on both VMs.

Verified 2026-11-21 (again after plan 03): each mock from a clean `make rebuild` (both VMs) in real exam mode, all reference solutions applied in order, score 98/98 for all 3.

## Changes to the UI after a rebuild

`make rebuild` uses the patched files, so the patches stay. To rebuild only the UI after a frontend change:

```bash
limactl shell k16s -- bash -lc 'sudo rm -f /usr/local/bin/k16s-server && sudo bash $HOME/k16s/provision/k16s-server.sh'
make clean
```

(The repo folder is mounted in the VM at `~/k16s`, so edits on the Mac are seen at once.)

## Keys and clipboard

- Use **Ctrl**, not Cmd, inside the desktop. Terminal: Ctrl+Shift+C / Ctrl+Shift+V. Firefox in the desktop: Ctrl+C / Ctrl+V.
- **Click-to-copy (patched into the exam UI):** click a highlighted text or code block in the question or guide, or select text there and press Cmd+C. The UI sends it to the desktop clipboard (it fills noVNC's clipboard box and fires its change event). Then paste with Ctrl+Shift+V (terminal) or Ctrl+V (Firefox in the desktop).
- Your own Firefox catches Ctrl+W (closes the tab). Same risk as in the exam.
- Fallback if keys break: a native VNC viewer (TigerVNC) with a Lima port forward of 5901. Not set up.

## Known limits versus the real exam

- Desktop is Openbox + sakura terminal, not XFCE.
- Workers are Incus LXC containers (Debian 12). That is why AppArmor, seccomp, Falco and gVisor tasks pin their pods to `controlplane` (a VM kernel).
- `ssh node01` / `ssh node02` log in as root, not as candidate. The workers have no kubectl.
- Host `base` is the main VM, so `sudo` works on base (not in the real exam).
- cilium-cp is one node: WireGuard encrypts nothing between nodes (0 peers). The task checks the agent state, not the traffic.
- No click-to-copy from the task into the desktop.

## Install history (for debugging)

1. `install.sh --laptop` failed (bash 3.2 bug). Workaround: extra flags.
2. First provision failed on `gnupg2`. Fixed with `apt-get update`, later patched in `lima.yaml`.
3. One `kubeadm init` failure, cause unknown (log lost). The next run passed with no change.
4. Desktop step failed the 20 GB free disk check. Fixed with cache cleanup, then 40 GB disk.
5. Final `make rebuild` ran clean from zero in about 6 min: v1.37.2, 3 nodes Ready, desktop active.
6. First rebuild with user-v2 failed: "Incus is not initialized". Cause: `incus storage list | grep -q` under pipefail (grep exits early, incus gets SIGPIPE). Fixed in `provision/incus.sh`.
