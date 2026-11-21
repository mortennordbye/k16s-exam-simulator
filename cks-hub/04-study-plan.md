# CKS study plan: minimum time (start 2026-11-21, exam 2026-12-17)

Goal: pass CKS once, which also renews the CKA. Study as little as possible, in short sessions after work.

## The method (why this is the fastest way)

1. **Learn by doing, never by reading.** Every session is lab tasks. When you are stuck, open the Guide (where to copy from), do it, move on.
2. **Short sessions: 30 to 45 min**, one topic each, in **Practice** mode (`make exam`, choose the drill, Mode: Practice).
3. **Only what scores.** Your gaps first (kubeadm control plane edits). Topics you know (NetworkPolicy, Falco, Trivy) get one quick pass.
4. **Repeat only your misses.** After each mock, the results page lists the items you lost. The next sessions are only those items.
5. **Mocks on weekends** (2 h each): 3 lab mocks in **Real exam** mode, plus the 2 killer.sh sessions.

Time in total: about 14 short sessions (about 9 h) and 5 mocks (about 12 h with review). Fridays and some evenings are free.

## How one session works (30 to 45 min)

1. `make up`, then `make exam`. Choose the drill and **Practice**.
2. Per task: **Setup Env**, solve it in the desktop, **Check Answer**. Under 10 min, else open **Show guide**.
3. A task with less than full points: do it again at once (Setup Env, then solve it from a blank terminal).
4. Write the time and the misses in the log at the end of this file. Stop at 45 min.
5. `make stop` when you finish (frees 8 GB RAM).

## Sessions

Drill names in the lab: **New topics** = the 16 new tasks (b01 to b16); **Drill 1, 2, 3** = the original topic drills.

| # | Date | Topic | Lab tasks (Practice mode) |
|---|---|---|---|
| 1 | Sat 11-21 | Lab and keys. `k` alias, `:set paste`, Ctrl+Shift+V, click-to-copy. | Drill 1: task 1 with the Guide |
| 2 | Sun 11-22 | **Static pod edits + audit logging** (your main gap) | New topics: b01 |
| 3 | Mon 11-23 | **Encryption at rest** + etcdctl | New topics: b02 |
| 4 | Tue 11-24 | **ImagePolicyWebhook**, anonymous access, NodeRestriction | New topics: b03, b16 |
| 5 | Wed 11-25 | **AppArmor** | Drill 1: 06, 07. Drill 2: the aa tasks |
| 6 | Thu 11-26 | **seccomp** | Drill 1: 09 to 12 |
| - | Fri 11-27 | free | |
| 7 | Sat 11-28 | **kube-bench, kubelet, binaries** | Drill 3: kube-bench and kubelet tasks. New topics: b13 |
| 8 | Sun 11-29 | **NetworkPolicy** (fast pass) | Drill 1: 01 to 05 |
| 9 | Mon 11-30 | **RBAC + ServiceAccount, PSA, Secrets** | New topics: b09, b08, b10 |
| 10 | Tue 12-01 | **gVisor, immutable container, Ingress TLS**. **Buy the exam today** (not CKS-SINGLE), book 12-17. | New topics: b07, b12, b11 |
| 11 | Wed 12-02 | **Supply chain**: Trivy, SBOM, kubesec, Dockerfile | New topics: b04, b05, b06 |
| 12 | Thu 12-03 | **Falco** | New topics: b14, b15 |
| - | Fri 12-04 | free | |
| M1 | Sat 12-05 | **Lab mock 1**, Real exam mode, 2 h. Then 20 min on the results. | CKS Mock 1 |
| K1 | Sun 12-06 | **killer.sh A**, 2 h. Read the solutions of what you missed. | killer.sh |
| 13 | Mon 12-07 | Misses from M1 and K1 | the tasks you lost |
| 14 | Tue 12-08 | Misses from M1 and K1 | the tasks you lost |
| 15 | Wed 12-09 | Misses, then doc search speed (find each page in under 20 s) | |
| - | Thu 12-10, Fri 12-11 | free | |
| M2 | Sat 12-12 | **Lab mock 2**, Real exam mode | CKS Mock 2 |
| K2 | Sun 12-13 | **killer.sh B** | killer.sh |
| 16 | Mon 12-14 | Misses from M2 and K2 | |
| 17 | Tue 12-15 | Misses. Optional: Lab mock 3, only the tasks you have not seen | CKS Mock 3 |
| - | Wed 12-16 | Light: PSI system check, keyboard test (`\|`, `{`, `~`, `$`), Bluetooth off | |
| **E** | **Thu 12-17** | **Exam** | |

## Ready check (before 12-17)

- killer.sh B: 60% or more, and you understand every miss.
- Lab mock 2: 75% or more in Real exam mode.
- The apiserver edits (audit, encryption, admission) take you under 8 min each.

If you are not ready on 12-13, move the exam (allowed until 24 h before). The CKA is valid until 2027-01-30, and you get a free retake.

## Exam day tactics

- Read all tasks first (5 min). Do the easy ones first. Flag and skip anything over 8 min.
- Run the `ssh` command of the task. Go back to `base` after.
- Back up a manifest to `/root/` before you edit it. While the apiserver restarts, read the next task.
- Partial work gives points: never leave a task blank.

## Your lab

| Task | Command |
|---|---|
| All commands | `make` |
| Start / stop | `make up` / `make stop` |
| Exam UI | `make exam` |
| Start over from zero (about 7 min) | `make rebuild` |

## Time log

| Date | Session | Time | Missed items |
|---|---|---|---|
| | | | |
