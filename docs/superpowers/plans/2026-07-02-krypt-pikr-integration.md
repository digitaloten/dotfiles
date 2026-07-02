# krypt/pikr Upstream Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the completed `origin/main` merge (branch `merge-origin`, commit
`24665bc`) onto the live `.files` dotfiles and switch the desktop menu/system
layer from `rofi` + `.menu-*` scripts to the upstream `krypt` (declarative
dotfiles manager) + `pikr` (rofi replacement) model — without breaking the
running Hyprland session.

**Architecture:** The full merge is already resolved in an isolated worktree
(`.claude/worktrees/merge-origin`, branch `merge-origin`, 2 parents: `624da01`
local HEAD + `8bb2525` origin/main). This plan (1) reconciles live uncommitted
tweaks into that branch, (2) installs the new AUR binaries, (3) seeds user-local
template files, (4) fast-forwards `main` to the merge, (5) deploys via `krypt`,
(6) verifies the desktop, with a rollback path at every stage.

**Tech Stack:** GNU Stow (current deploy) → krypt (new deploy); Hyprland,
waybar, fish, tmux, Neovim; AUR (`paru`); `pikr` menu picker; Arch Linux.

## Global Constraints

- **⚠️ STOW HAZARD (learned the hard way in Task 2):** the repo is deployed via
  GNU Stow, so `~/.config/*` are symlinks pointing AT the tracked repo files —
  editing a tracked file (git checkout/stash/merge) mutates the LIVE config in
  place. Hyprland (running, live-watches its config) auto-reloads on any change
  to `hyprland.conf`; if it reads an incomplete/invalid file mid-write, or a
  `source=`'d include is missing, it **overwrites the file with an emergency
  stub** (`# This config is a STUB!`). This already happened once when
  `git stash` reverted `hyprland.conf`. Mitigations, applied below: (a) never
  leave `hyprland.conf` in a state that `source`s a missing file — seed all
  `~/.config/hypr/*.conf` includes FIRST (Task 4, before the Task 5 merge); (b)
  restore a clobbered file in-place with `git show HEAD:<path> > <path>`
  (truncate+write, no unlink/rename race), never `git checkout` (which failed
  with "File exists" during the race); (c) run `hyprctl reload` explicitly after
  restoring.
- Tasks 1–4 install packages and stage git/template state; the git-branch work
  is reversible, but per the hazard above, changes to stow-symlinked tracked
  files are NOT invisible to the live session.
- **Do not delete the `merge-origin` worktree until Task 8 confirms success.**
  It is the rollback anchor.
- Merge base is `bdaac56` (2024-08-06); the two histories diverged ~2 years.
  Assume nothing about upstream is a superset — verify each behavior.
- Repo commit rule: `git commit -m "$(quoty)"` in the `.files` repo ONLY.
- Markdown edits → `prettier --write <file>`.
- Required new binaries: `krypt`, `pikr`. Neither is currently installed
  (`command -v krypt pikr` → empty). `rofi` is still installed and is the
  current working launcher.
- Live desktop must stay usable; if a step breaks the session, use the Task 9
  rollback before continuing.

---

## Pre-flight: State Snapshot (read before starting)

Current facts captured during the merge (2026-07-02):

- **`main` working tree has 3 uncommitted files** — live tweaks NOT in the merge
  (worktree branched from committed HEAD):
  - `.config/opencode/opencode.json` — ollama endpoint changed to
    `http://137.175.76.24:20678/v1` + `apiKey: sk-noauth` + model
    `unsloth/Qwen3.6-35B-A3B-NVFP4` (ctx 262144 / out 32768). **This is the
    current working LLM endpoint.** The merge took upstream's opencode.json
    (llama-cpp + ollama@`10.0.1.1` + lmstudio) which does NOT contain this
    endpoint.
  - `.claude/settings.json` — adds `"Bash(ssh agent@*)"` permission,
    `effortLevel: xhigh`, `verbose: true`. The merge kept committed HEAD's
    `effortLevel: medium`.
  - `.config/hypr/hyprland.conf` — removed `vfr = true` and `pseudotile = true`.
    The merge took upstream's fully-restructured hyprland.conf (these local
    edits are moot — upstream reorganized the whole file).
- **Merge decisions taken that overwrite personal config** (verify each in Task
  6):
  - `.codex/config.toml` → upstream: **lost** the local `ollama-launch` profile
    (`pc.mx.kryptic.sh`) and `[projects."/home/mxaddict"]`; gained `gpt-5.5`,
    `guardian_subagent`, shinobu project paths.
  - `.config/opencode/opencode.json` → upstream providers (see above).
  - `.config/hypr/hyprpaper.template.conf` → wallpaper `shinobu.jpg` (was
    `exfil.png`; `exfil.png` is NOT in the repo, `shinobu.jpg` IS).
  - `.config/hypr/hyprlock.conf` → **kept local** `fingerprint:enabled = true`
    (upstream disabled it).
  - `.claude/settings.json`, `.config/tmux/tmux.conf`,
    `.config/gtk-3.0/settings.ini`, `.config/agents/AGENTS.md` → unioned (both
    sides kept).
- **`.config/hypr/hyprpaper.conf` is tracked** (150B, live file) but upstream's
  model gitignores it and seeds it from the template. It still points to the
  stale `exfil.png`.
- **`.gitconfig` identity is now externalized**: merged `.gitconfig` is
  `[include] path = ~/.gitconfig.local`. `~/.gitconfig.local` does not exist
  yet. Local identity to preserve: `name = shinobu`, `email = pekora@usada.io`,
  `signingkey = pekora@usada.io`.
- New AUR deps (`.krypt/deps.toml` group `aur-tools`): `krypt-bin`, `pikr-bin`,
  `hjkl-bin`, `sqeel-bin`, `buffr-bin`, `hodl-bin`, `inbx-bin`, `gemini-cli`.
- hyprland binds now call
  `krypt menu {apps,calc,emoji,wifi,power,audio,bluetooth,time,top}`,
  `krypt menu autofill -- {auth,user,pass,otp}`, `krypt system start`,
  `krypt kanata toggle`. waybar `on-click` →
  `krypt menu {bluetooth,wifi,power,audio}`.
- `.menu-*` scripts now shell out to `pikr` instead of `rofi`.

---

## Task 1: Install krypt + pikr (and AUR tooling)

**Files:** none in repo — system package install only.

**Interfaces:**

- Produces: working `krypt` and `pikr` binaries on `$PATH`, consumed by every
  later task and by the hyprland/waybar binds.

- [x] **Step 1: Confirm an AUR helper exists** — DONE: `/usr/sbin/paru`.

- [x] **Step 2: Install the two required binaries** — DONE:
      `paru -S --needed --noconfirm krypt-bin pikr-bin` installed `krypt-bin`
      and `pikr-bin 0.8.6-1`.

- [x] **Step 3: Verify the binaries run** — DONE: `krypt 0.2.2`
      (`/usr/sbin/krypt`), `pikr 0.8.6` (`/usr/sbin/pikr`). krypt ≥ 0.1.0 ✓.

- [x] **Step 4: Discover krypt's CLI surface** — DONE (krypt 0.2.2)

Verified subcommands (used by later tasks):

- `krypt link` — deploy every `.krypt.toml` entry; idempotent. **Skips
  destinations whose content isn't tracked by its manifest (i.e. existing stow
  symlinks) unless `--force`.** → Task 7 uses `krypt link --force`.
- `krypt setup --prompts <name>` — run `[prompts.*]` wizard(s) (`git`,
  `hypr_apps`, `hypr_input`), writing user-local files. → Task 4.
- `krypt diff` — compare deployed files vs manifest (dry-run preview). → Task 7.
- `krypt validate` — parse/validate `.krypt.toml`. Already run on the merged
  manifest: **✓ passes**.
- `krypt deps` — install `[[deps]]` packages via the platform package manager. →
  Task 7.
- `krypt doctor` — full diagnostic health-check. → Task 8.
- `krypt relink` / `unlink` / `adopt` / `paths` / `menu` / `update` — available.

- [x] **Step 5: Install the rest of the AUR tools** — DONE:
      `paru -S --needed --noconfirm hjkl-bin sqeel-bin buffr-bin hodl-bin     inbx-bin gemini-cli`
      (exit 0). Verified: `hjkl` `sqeel` `hodl` `inbx` in `/usr/sbin`, `buffr`
      in `~/.cargo/bin`, `gemini` via fnm shim.

_No commit — system state only._

---

## Task 2: Preserve live uncommitted tweaks before they are lost

The 3 uncommitted files in `main` carry current settings the merge does not
have. Capture them so Task 5's merge doesn't silently discard them.

**Files:**

- Modify (main working tree, then stash): `.config/opencode/opencode.json`,
  `.claude/settings.json`, `.config/hypr/hyprland.conf`

**Interfaces:**

- Produces: a saved patch
  `/home/shinobu/.files/docs/superpowers/plans/live-tweaks-2026-07-02.patch` and
  a clean `main` working tree, consumed by Task 5 (merge) and Task 6
  (reconcile).

- [x] **Step 1: Save the live tweaks as a patch** — DONE: 105-line patch at
      `docs/superpowers/plans/live-tweaks-2026-07-02.patch` (3 files, 29 line
      changes).

- [x] **Step 2: Confirm the patch captured everything** — DONE:
      `git apply --check --reverse` → `patch matches working tree`.

- [x] **Step 3: Stash the working tree** — DONE:
      `git stash push -m "live tweaks pre-krypt-merge" -- <3 files>`.
      `stash@{0}` holds all 3; tracked tree clean.

  **⚠️ INCIDENT during this step (see STOW HAZARD):** the stash's revert of the
  stow-symlinked `hyprland.conf` raced Hyprland's live config watcher → Hyprland
  wrote an emergency STUB into the repo file. Recovered by
  `git show HEAD:.config/hypr/hyprland.conf > .config/hypr/hyprland.conf` (NOT
  `git checkout`, which failed "File exists" mid-race) + `hyprctl reload` (→
  `ok`, 86 binds restored). No data lost — the 2-line hyprland tweak is safe in
  both the stash and the patch, and is moot (upstream restructures the file).

_No commit — stash + patch are the record._

---

## Task 3: Fold the important live tweaks into the merge branch

Re-apply the settings worth keeping onto `merge-origin` so the landed result
reflects real current prefs, not stale committed HEAD.

**Files:**

- Modify: `.config/opencode/opencode.json` (add the live ollama endpoint back)
- Modify: `.claude/settings.json:107` (`effortLevel`), permissions allow-list,
  `verbose`

**Interfaces:**

- Consumes: `docs/superpowers/plans/live-tweaks-2026-07-02.patch` from Task 2.
- Produces: an updated `merge-origin` tip with reconciled personal settings,
  consumed by Task 5.

- [x] **Step 1: Switch into the merge worktree** — DONE.

- [x] **Step 2: Set `effortLevel` to xhigh + ssh permission** — DONE:
      `.claude/settings.json` in worktree → `effortLevel: xhigh`, added
      `"Bash(ssh agent@*)"`; `verbose: true` already present.

- [x] **Step 3: Restore the live opencode.json** — DONE. Decision: took your
      FULL live opencode.json (providers `ollama` @ `137.175.76.24:20678` +
      `vllm` RunPod) instead of surgically patching upstream's — upstream's
      providers (`llama-cpp`/`lmstudio`/`10.0.1.1`) are digitaloten's, not
      yours. Fixed a trailing comma (line 18) that made your live file invalid
      strict JSON (opencode's parser tolerated it; jq/prettier didn't). Any
      upstream providers you want back → add in Task 6.

- [x] **Step 4: Commit the reconciliation** — DONE: `db08f7c` on `merge-origin`
      (parent = merge `24665bc`; chain verified).

---

## Task 4: Seed user-local template files

krypt's model keeps machine-local files OUT of the repo, seeded from
`*.template.*`. These must exist before Task 5's deploy or hyprland `$vars` and
git identity break.

**Files:**

- Create: `~/.gitconfig.local` (from `.gitconfig.local.template`)
- Create: `~/.config/hypr/apps.conf`, `~/.config/hypr/input.conf`,
  `~/.config/hypr/monitors.conf`, `~/.config/hypr/hyprpaper.conf` (from their
  templates)

**Interfaces:**

- Consumes: template files present in `merge-origin`
  (`.gitconfig.local.template`,
  `.config/hypr/{apps,input,monitors,hyprpaper}.template.conf` — all verified
  present).
- Produces: populated `~/.gitconfig.local` and `~/.config/hypr/*.conf` live
  files, consumed by hyprland at reload (Task 7) and git at commit time.

- [ ] **Step 1: Seed git identity**

The merged `.gitconfig` is now `[include] path = ~/.gitconfig.local`. Create
`~/.gitconfig.local` with your identity:

```ini
[user]
	name = shinobu
	email = pekora@usada.io
	signingkey = pekora@usada.io
```

- [x] **Step 1: Seed git identity** — DONE: wrote `~/.gitconfig.local` by hand
      (non-interactive; `krypt setup --prompts git` would block on stdin) with
      `name=shinobu`, `email=pekora@usada.io`, `signingkey=pekora@usada.io`.
      `git config --file ~/.gitconfig.local user.email` → `pekora@usada.io`.

- [x] **Step 2: Verify git sees the identity through the include** — DONE:
      confirmed `~/.gitconfig.local` resolves (post-merge `.gitconfig` uses
      `[include]`). Current pre-merge `.gitconfig` still has identity inline —
      the include takes over after Task 5.

- [x] **Step 3: Seed the hyprland app/input/monitor/wallpaper confs** — DONE.
      State on disk: `monitors.conf` (202B) + `workspaces.conf` (141B) already
      existed as real local files; `hyprpaper.conf` exists (symlink → repo).
      Created `apps.conf` + `input.conf` via `cp -n` from templates (defaults
      match your setup exactly — alacritty/.browser/nautilus/hyprlock/
      hyprpicker/grimblast/kooha; input kb_layout=us). These are unreferenced by
      the pre-merge hyprland.conf, so no live reload was triggered.

- [x] **Step 3b: Confirm every `source=` in merged hyprland.conf resolves** —
      DONE: all 4 (`monitors`, `workspaces`, `apps`, `input`) → OK, 0 missing.

- [x] **Step 4: Verify the `$var` app launchers resolve** — DONE: all 8 vars
      used by merged hyprland.conf
      (`terminal browser filemanager lock     colorpicker screenshot record notify`)
      are defined in `apps.conf`. No undefined vars → merge will not
      stub-clobber.

_No repo commit — these live files are gitignored by design._

---

## Task 5: Land the merge onto `main`

**Files:**

- Modify: `main` branch ref (fast-forward / merge to `merge-origin`)

**Interfaces:**

- Consumes: reconciled `merge-origin` tip (Task 3), seeded templates (Task 4),
  installed binaries (Task 1).
- Produces: `main` pointing at the integrated tree; the repo is now
  krypt-shaped.

- [x] **Step 0: Pre-merge safety gate (STOW HAZARD)** — DONE: all 4 `source=`
      targets (monitors/workspaces/apps/input) resolve, 0 missing.

- [x] **Step 1: Return to the main checkout and confirm it's clean** — DONE: on
      `main` @ `624da01`, tracked tree clean.

- [x] **Step 2: Merge the reconciled branch into main** — DONE:
      `git merge --no-ff merge-origin` → HEAD `926ff60` (parents `624da01` +
      `db08f7c`).

Expected: merges cleanly (no conflicts — `merge-origin` already contains
`main`'s HEAD `624da01` as a parent, so this is effectively a fast-forward of
resolved content). Hyprland will auto-reload from the new `hyprland.conf`.

- [x] **Step 2b: Confirm Hyprland did not stub-clobber** — DONE: real config
      intact (266 lines, NO stub), `hyprctl reload` → `ok`, 86 binds loaded.
      Includes all resolved → clean reload, first try.

- [x] **Step 3: Verify the tree matches the merge branch exactly** — DONE:
      `git diff merge-origin HEAD --stat` → empty (identical). Bonus:
      `.gitconfig` include resolves `shinobu <pekora@usada.io>`;
      `krypt validate` on live manifest → ✓.

- [x] **Step 2c: Register the krypt repo path (REQUIRED for `krypt menu`
      binds)** — DONE. Discovered gap: the merged hyprland/waybar binds call
      `krypt menu X` with no `--config`, and Hyprland runs them from `$HOME`
      (not the repo), so krypt could not find `.krypt.toml` → every menu bind
      failed. Fix: krypt reads a tool config at `~/.config/krypt/config.toml`
      that records the repo path. Wrote:

  ```toml
  [repo]
  path = "/home/shinobu/.files"
  ```

  (This file is a local, non-stow-managed tool config — the normal `krypt init`
  flow writes it, but init wants to clone to `${XDG_CONFIG}/krypt/repo`; our
  repo already lives at `~/.files`, so we point the config there by hand.)
  Verified: `krypt menu` from `$HOME` lists all 13 menus; dry-runs correct
  (`apps`→`pikr -s drun`, `calc`→`pikr --show calc`, `wifi`/`power`→their
  pikr-backed scripts).

- [ ] **Step 4: Drop the stash — DEFERRED until Task 8 verifies the desktop.**

The stashed tweaks were folded into `merge-origin` (Task 3) or superseded by
upstream's hyprland.conf, so the stash is redundant — BUT keeping it costs
nothing and adds a rollback net through the live cutover. Drop it only after
Task 8 confirms the desktop is healthy:

```bash
git stash show -p stash@{0} | head -40   # review
git stash drop stash@{0}
```

Expected: stash dropped. `live-tweaks-2026-07-02.patch` remains the durable
backup regardless.

---

## Task 6: Reconcile personal config the merge overwrote

Upstream's versions replaced several personal files. Decide keep-vs-restore for
each, on `main`, now that it's landed.

**Files:**

- Review/Modify: `.codex/config.toml`, `.config/opencode/opencode.json`

**Interfaces:**

- Consumes: `live-tweaks-2026-07-02.patch` and git history
  (`git show 624da01:<path>`) as the source of the old values.

- [ ] **Step 1: Decide the codex provider config**

The merge dropped the local `ollama-launch` profile (`pc.mx.kryptic.sh`).
Recover the old block if still wanted:

```bash
git show 624da01:.codex/config.toml
```

- [x] **Step 1: codex provider config — DECISION: keep upstream.** User chose to
      keep upstream's `gpt-5.5`/`guardian_subagent` config; the old
      `ollama-launch` profile (`pc.mx.kryptic.sh`) is NOT re-added.
      `.codex/config.toml` validates as TOML. No edit.

- [x] **Step 2: opencode provider set** — already finalized in Task 3 (your live
      providers `ollama` @ `137.175.76.24` + `vllm` RunPod). No further change.

- [x] **Step 3: no reconciliation commit needed** (kept upstream codex; opencode
      done in Task 3).

---

## Task 7: Deploy with krypt + untrack the live hyprpaper.conf

Switch the deploy mechanism from stow to krypt and fix the one
tracked-live-file.

**Files:**

- Modify: repo tracking of `.config/hypr/hyprpaper.conf` (`git rm --cached`)
- Modify: live `~/.config` + `~/.local/bin` symlinks (via krypt)

**Interfaces:**

- Consumes: installed `krypt` (Task 1), the exact deploy/link subcommand
  recorded in Task 1 Step 4.
- Produces: live symlinks pointing at the new tree; a running krypt-managed
  desktop.

- [ ] **Step 1: Untrack the live hyprpaper.conf (upstream gitignores it)**

```bash
cd /home/shinobu/.files
git rm --cached .config/hypr/hyprpaper.conf
git commit -m "$(quoty)"
```

Expected: removed from index, still on disk.
`git check-ignore .config/hypr/hyprpaper.conf` now returns the path (ignored).
Your live `~/.config/hypr/hyprpaper.conf` (seeded in Task 4 from the
`shinobu.jpg` template) is untouched.

- [x] **Step 1: Untrack hyprpaper.conf** — DONE (`git rm --cached`, committed
      `dc81bae`-range). Now gitignored; live wallpaper (`shinobu.jpg`) intact.

- [x] **gtk-4.0 links.toml fix (prerequisite discovered)** — DONE, committed.
      `krypt` is COPY-based and FOLLOWS symlinks;
      `src_glob .config/gtk-4.0/**/*` followed the repo's `assets/`, `gtk.css`,
      `gtk-dark.css` symlinks (→ root-owned `/usr/share/themes/adw-gtk3-dark`)
      and copied THROUGH the live dst symlinks into `/usr/share` → Permission
      denied, aborting the first `krypt link`. `exclude` is not a supported
      links.toml key (verified). Fix: replaced the glob with explicit `[[link]]`
      for `colors.css` + `settings.ini` only; the 3 theme files stay
      theme/nwg-look-managed.

- [x] **Step 3: `krypt link --force`** — DONE (`wrote: 672`, manifest at
      `~/.local/state/krypt/manifest.json`). hyprland did NOT stub;
      `hyprctl     reload` → ok.

  **⚠️ `--force` re-seeds `[[template]]` files — CASUALTIES:**
  - `~/.gitconfig.local` → overwritten with the template placeholder →
    **RESTORED** (shinobu/pekora). krypt now reports it "drifted" — that is
    CORRECT (it will not overwrite it again without `--force`).
  - `~/.config/hypr/monitors.conf` → overwritten with the generic
    `monitor=,preferred,auto,1` fallback. Old config was already STALE
    (DP-3/DP-4; current hardware is DP-5/DP-6/eDP-1). Display works (all
    monitors on, but **eDP-1 re-enabled** — was `disable`). **USER ACTION: run
    `nwg-displays`** to regenerate for current hardware. Not auto-fixable
    (layout is a preference).
  - `apps.conf`/`input.conf`/`hyprpaper.conf` → template == your values, no real
    change.

  Lesson: `--force` is needed once to take over stow, but it clobbers seeded
  templates. Future deploys use plain `krypt link` / `krypt update` (no --force)
  which leave seeded files alone.

- [x] **Step 4: Complete the copy-model conversion (dir-symlinks → real
      copies)** — DONE. After `--force`, 18 `~/.config` dirs were still stow
      DIR-symlinks (krypt had written its file-links THROUGH them into the repo,
      leaving the dirs symlinked = still edit-live). Removed 17 of them and
      re-ran plain `krypt link` (no --force) → recreated as real copies
      (`wrote: 671`). Left `gtk-4.0` as a dir-symlink (its theme symlinks aren't
      krypt-deployed; converting would strip gtk4 theming).

  **Two dirs were NOT in `links.toml` at all** (stow deployed the whole tree;
  krypt only deploys explicit entries): `qutebrowser` (untracked runtime data)
  and `Vieb` (tracked `viebrc`+`colors`). Removing their symlinks orphaned them
  → **RESTORED as symlinks**. If you want them krypt-managed, add `[[link]]`
  entries to `.krypt/links.toml`.

- [x] **Step 4b: Verify** — 15 dirs now real copies; file-configs (mimeapps,
      starship, chromium-flags, user-dirs) real copies; `~/.local/bin/*` copies;
      `krypt diff` → 671 clean, only `.gitconfig.local` drifted (correct).
      Remaining intentional symlinks: `gtk-4.0`, `qutebrowser`, `Vieb`,
      `~/.gitignore`, `~/.agents`. waybar reloaded (SIGUSR2); hyprctl reload ok;
      86 binds; 13 menus; identity `pekora@usada.io`; repo clean.

- [ ] **Step 5: (Optional) run krypt deps to reconcile packages**

Run: `krypt deps`. Expected: installs any missing packages from
`.krypt/deps.toml`. Review before confirming — the `system`/`media` groups are
large. Skip groups you don't want. NOT run yet.

---

## Task 8: Verify the desktop end-to-end

**Files:** none — runtime verification.

**Interfaces:**

- Consumes: deployed links (Task 7), installed `krypt`/`pikr` (Task 1), seeded
  apps.conf (Task 4).

- [ ] **Step 0: Run krypt's own health check**

```bash
cd /home/shinobu/.files && krypt doctor && krypt diff
```

Expected: doctor reports healthy; `krypt diff` shows no differences (deploy
matches manifest). Fix anything doctor flags before touching Hyprland.

- [ ] **Step 1: Reload Hyprland**

Run: `hyprctl reload` Expected: `ok`, no parse errors. If it errors, read the
message — most likely a missing `~/.config/hypr/*.conf` include (re-check
Task 4) — and roll back (Task 9) if the session is unusable.

- [ ] **Step 2: Test each menu bind (pikr-backed)**

Trigger each and confirm a `pikr` window appears (not an error / not `rofi`):

- `$mod+space` → apps · `$mod+r` → calc · `$mod+period` → emoji · `$mod+w` →
  wifi
- `$mod+shift+m` → power · `$mod+a` → audio · `$mod+u` → bluetooth · `$mod+t` →
  time

Or from a terminal: `krypt menu apps`, `krypt menu calc`, `krypt menu wifi`.
Expected: each launches. If `krypt: command not found` or
`pikr: command not found` → Task 1 incomplete.

- [ ] **Step 3: Test autofill + system binds**

`$mod+ctrl+j/k/l/;` → `krypt menu autofill -- auth/user/pass/otp` (needs `pass`
store). `$mod+shift+g` → `krypt system start`. `ctrl+shift+k` →
`krypt kanata toggle`. Expected: each runs its underlying script without
`command not found`.

- [ ] **Step 4: Verify waybar renders and its click handlers work**

Run: `pkill waybar; waybar &` then click the power / wifi / bluetooth / audio
modules. Expected: waybar starts clean; clicks invoke `krypt menu <x>`.

- [ ] **Step 5: Verify the claude statusline still renders**

Open a new Claude Code session (or check the current one). Expected: statusline
shows dir/branch/tokens/context/model/effort + the new rate-limit bars
(upstream's statusline is a superset).

- [ ] **Step 6: Verify git identity on a real commit**

Run: `git -C /home/shinobu/.files log -1 --format='%an <%ae>'` Expected:
`shinobu <pekora@usada.io>` (proves `~/.gitconfig.local` include works).

---

## Task 9: Rollback procedure (only if Task 8 fails badly)

**Files:** `main` branch ref, live symlinks.

- [ ] **Step 1: Restore the pre-merge branch state**

```bash
cd /home/shinobu/.files
git reset --hard 624da01           # pre-merge local HEAD
git stash pop 2>/dev/null || git apply docs/superpowers/plans/live-tweaks-2026-07-02.patch
```

Expected: tree back to pre-integration + live tweaks restored.

- [ ] **Step 2: Re-deploy the old rofi-based layout**

Run: `stow .` (or the repo's prior stow invocation) to restore stow symlinks,
then `hyprctl reload`. Expected: rofi menus work again. `merge-origin` worktree
remains intact for a second attempt.

- [ ] **Step 3: Only after a SUCCESSFUL Task 8 — clean up**

```bash
git worktree remove .claude/worktrees/merge-origin
git branch -d merge-origin
```

Expected: worktree + branch removed. Do NOT run this until the desktop is
confirmed working.

---

## Self-Review Notes

- **Deploy-mechanism switch (stow → krypt)** is the highest-risk step (Task 7).
  Both create symlinks into the same repo, so the transition is mostly
  idempotent, but krypt's exact link subcommand/flags are version-dependent —
  Task 1 Step 4 records them authoritatively.
- **Data-loss guards:** live tweaks are saved to a patch (Task 2) before any
  stash/merge; old config values are recoverable from git
  (`git show 624da01:<path>`); the merge branch and worktree survive until Task
  9 Step 3.
- **Not automated here:** exact krypt CLI flags (unknown until installed), and
  the personal keep-vs-restore calls for codex/opencode providers (Task 6) —
  these need your judgment on which endpoints you actually use.
- **Fork identity note:** `origin` = digitaloten, `fork` = mxaddict. Local HEAD
  carried stale `/home/mxaddict/` paths (`.codex`); the merge adopts upstream's
  correct `/home/shinobu/` paths. The separate `fork/main` reconciliation
  (behind 62 / ahead 1196) is explicitly out of scope — a later task.
