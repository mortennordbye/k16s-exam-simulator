# Plan: fork K16S and build the CKS hub changes

Date: 2026-11-21. Status: waiting for yes.

## What changes and why

You practise in K16S. Today the changes live only as uncommitted edits in `repos/k16s-exam-simulator` and a patch file. A fork on your GitHub keeps them safe, versioned and easy to rebuild. Then I add the two features we talked about but did not build.

## Already done (local, not committed)

1. `local/lima.yaml`: `apt-get update` at boot (fixes the `gnupg2` install failure).
2. `provision/desktop.sh`: Openbox opens windows maximized.
3. Exam UI (`+page.svelte`, `lib/guide.js`, `lib/guide.md`):
   - Desktop panel first, full noVNC page (clipboard), remote resize.
   - Click-to-copy from question and guide into the desktop.
   - Draggable divider, default 25%.
   - Guide button per task, with full kubernetes.io manifests at the bottom.

## New work

4. **Fix `install.sh --laptop` on macOS bash 3.2** (`LAPTOP_ARGS[@]: unbound variable`). Proper fix, not the Makefile workaround.
5. **Partial scoring, like the real exam and killer.sh.** Each check script runs all checks and prints one line per check. The server counts them. A task gives `weight x passed/total` points.
6. **Exam mode.** A switch on the start page. When it is on, Check Answer and the Guide button are hidden until you press End Exam. Then all tasks are graded at once and the results page shows the points per task and per check.

## Picture of the result

Before (task panel, bottom):
```
[ Setup Env ]  [ Check Answer ]      -> "FAIL: manifest not saved ..."   (0 of 4 pts)
```
After, practice mode:
```
[ Setup Env ]  [ Check Answer ]
  3/4 checks   3.0 of 4 pts
  ✓ policy web-ingress-allow exists
  ✓ podSelector app=backend
  ✓ ingress frontend:8080 and monitoring:9100
  ✗ manifest saved to /opt/cks-netpol/web-ingress-allow.yaml
```
After, exam mode (during the exam): no Check Answer, no Guide. Only [ Setup Env ].
Results page after End Exam:
```
Task                                   Points     Checks
 1 Restrict Pod Ingress (NetworkPolicy)  3.0 / 4    3/4   (click to open the check list)
 2 Egress Controls                        6.0 / 6    5/5
 ...
Total                                   61 / 100   pass mark 67
```

## What does not change

- The tasks, their text, setup scripts and the cluster.
- Your hub commands (`make up`, `make exam`, ...). Only the repo source changes to your fork.
- The original license (PolyForm Noncommercial). The fork keeps LICENSE and the copyright notice. Personal, noncommercial use is allowed.

## Steps in order

1. `gh repo fork immanuwell/k16s-exam-simulator` to `mortennordbye/k16s-exam-simulator` (a fork of a public repo is public). Local remotes: `origin` = your fork, `upstream` = original.
2. Branch `cks-hub`. Commit the done work (1 to 3) as small commits. Drop the `package-lock.json` noise.
3. Fix 4. Test: `bash install.sh --laptop --profile cks` with no extra flags reaches the VM step.
4. Partial scoring (5): convert the 51 CKS check scripts (cks, cks2, cks3) to the new output, server change, UI change. Keep old scripts working (a script with no check lines still counts as pass or fail).
5. Exam mode (6): UI switch, hide buttons, grade all on End Exam, results page.
6. `make rebuild` from zero, then run a full CKS mock on the fork.
7. Open a PR in your fork (`cks-hub` to `main`), merge after the checks. The CKS folder Makefile and docs point to the fork.

## How you check the result

- `make rebuild` works from zero with no manual step.
- Task 1 with the file missing shows 3/4 checks and 3.0 of 4 points.
- In exam mode, Check Answer and Guide are hidden. End Exam shows the results table.
- Your GitHub has the fork with the `cks-hub` changes merged.

## Decisions for you

- A. OK that the fork is public? (GitHub forks of public repos are always public.)
- B. Also send the 2 bug fixes (gnupg2, macOS bash) upstream as small PRs to immanuwell? My default: no, unless you say yes.
- C. Not in scope: the Esc key problem (cause still unknown, it needs your 2 tests first).
