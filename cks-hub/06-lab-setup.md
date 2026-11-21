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
| **`make exam` is the only place to practise** | Questions left, remote desktop right, like the real exam. |
| Firefox on the Mac | The exam desktop uses Firefox for docs. |
| Exam bought later | Buy by 2026-12-01 so killer.sh A (12-06) and B (12-13) still fit. Exam target 2026-12-17. |

## Local patches to K16S

K16S commit: `08f0ba1`. All patches are in `patches/k16s-exam-simulator.patch`.
Save them with `make patch` (`make ui` and `make guide` do this for you). If you clone K16S again, apply them: `git -C repos/k16s-exam-simulator apply ../../patches/k16s-exam-simulator.patch`

1. `local/lima.yaml`: runs `apt-get update` at boot. Without it the first install fails: `E: Package 'gnupg2' has no installation candidate` (stale apt lists in the Ubuntu image).
2. `server/frontend/src/routes/+page.svelte`:
   - The Desktop panel uses `vnc.html` (full noVNC, has a clipboard panel), not `vnc_lite.html` (no clipboard).
   - The right panel opens on Desktop, not Terminal.
   - Layout: draggable divider between the question and the desktop (default 25%, saved in the browser, double-click resets). The desktop uses noVNC `resize=remote`, so the Linux screen fills the panel.
   - **Guide button** ("Show guide (where to copy from)") under each task. It shows the matching sections of `07-scaffolds.md` (code in `src/lib/guide.js`, task id keyword to section rules). After you edit `07-scaffolds.md`, run `make guide`.

3. `provision/desktop.sh`: Openbox opens every window maximized (also applied live to `/home/candidate/.config/openbox/rc.xml`).

Not patched, avoided instead: `install.sh --laptop` fails on macOS bash 3.2 with `LAPTOP_ARGS[@]: unbound variable` when no laptop flags are given. The Makefile calls `local/k16s-local up` directly with all flags.

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
- Workers are Incus LXC containers (Debian 12). AppArmor and Falco tasks can act differently. Use killer.sh and Killercoda for those.
- No click-to-copy from the task into the desktop.

## Install history (for debugging)

1. `install.sh --laptop` failed (bash 3.2 bug). Workaround: extra flags.
2. First provision failed on `gnupg2`. Fixed with `apt-get update`, later patched in `lima.yaml`.
3. One `kubeadm init` failure, cause unknown (log lost). The next run passed with no change.
4. Desktop step failed the 20 GB free disk check. Fixed with cache cleanup, then 40 GB disk.
5. Final `make rebuild` ran clean from zero in about 6 min: v1.37.2, 3 nodes Ready, desktop active.
