# CKS hub (study folder)

Copy of the study folder that drives this fork (plan, drills, scaffolds, lab notes, Makefile). The Makefile expects this repo at `repos/k16s-exam-simulator` next to it.


Start here. Run `make` in this folder to see all commands (lab, plan, docs).

| File | What |
|---|---|
| [04-study-plan.md](04-study-plan.md) | **The plan.** Day by day to the exam on 2026-12-17. Time log at the end. |
| [07-scaffolds.md](07-scaffolds.md) | **Where to copy each YAML from** (doc page, example, what to change) and the kubectl generators. Use this, not memory. |
| [05-drills.md](05-drills.md) | The 14 core drills with commands and YAML. Practise these. |
| [02-exam-facts.md](02-exam-facts.md) | Exam rules, weights, allowed docs, CKA renewal rule, traps. |
| [03-tools-and-labs.md](03-tools-and-labs.md) | Simulators ranked, local lab recipe (Multipass + kubeadm). |
| [08-exam-environment.md](08-exam-environment.md) | Real exam environment vs our lab: CNI, tools, topics, what not to train. |
| [06-lab-setup.md](06-lab-setup.md) | How the lab is built, local patches, decisions, known limits. |
| `repos/k16s-exam-simulator` | The lab: your fork of K16S (https://github.com/mortennordbye/k16s-exam-simulator). |

## Today

1. `make up`, then `make exam`. Questions left, remote desktop right, like the real exam.
2. Buy the CKS (not "CKS-SINGLE") by 2026-12-01. Book 2026-12-17.
3. Start Day 2 in `04-study-plan.md`.
