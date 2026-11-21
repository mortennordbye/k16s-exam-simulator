# Plan 03: make the lab match the real exam environment

Date: 2026-11-21. Status: approved ("do it"), items 1 to 4. Item 5 (Istio, host footprint) is backlog.
Source: 08-exam-environment.md.

## What changes and why

1. **Second cluster with Cilium** (CNI likely differs per exam cluster; CiliumNetworkPolicy reported in 2025). A small second Lima VM, kubeadm, Cilium with WireGuard. Tasks: CiliumNetworkPolicy (L3/L4, deny), check pod-to-pod encryption is on.
2. **kubeadm upgrade task** (in the curriculum, no task today). Runs on a cluster one minor version below (v1.36 to v1.37), so it does not touch the main cluster.
3. **Exam host flow.** The desktop terminal is `base` with no kubectl. Each task names its host; you `ssh <host>`, work, `exit`.
4. **Node-level tasks on a real VM node.** AppArmor, seccomp, Falco and gVisor tasks run on a VM kernel node, not on an LXC worker.

## Picture

Before: one cluster (controlplane VM + node01/node02 LXC). Terminal opens on controlplane with kubectl ready.
After:
```
base (desktop terminal, no kubectl)
 ├─ ssh controlplane   main cluster, Calico, v1.37  (most tasks)
 ├─ ssh node01/node02  workers (LXC)
 └─ ssh cilium-cp      second cluster, Cilium + WireGuard (Cilium tasks, upgrade task)
Task box: "Solve this task on: ssh cilium-cp"
```

## What does not change

Real exam mode, partial scoring, the 3 mocks (they get new tasks swapped in, still about 98 points), the hub commands.

## Steps

1. Design note (resources, network between VMs, how setup/validate reach the second cluster, reset of the upgrade task).
2. Build, then test each new task (0 before, PASS with solution, shortcut fails).
3. Swap the new tasks into the mocks (keep domain balance), mocks end to end 98/98 from `make rebuild`.
4. PR in the fork. Review, then squash merge.

## How you check

`make rebuild`, `make exam`, a Cilium task says "ssh cilium-cp" and works there; the terminal starts on base without kubectl; the upgrade task upgrades v1.36 to v1.37.
