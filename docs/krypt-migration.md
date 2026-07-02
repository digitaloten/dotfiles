# krypt / pikr Migration Notes

**Date:** 2026-07-02 **Applies to:** this `.files` repo after merging upstream
`origin/main` (digitaloten) — the `rofi` + GNU Stow + `.menu-*` era → `krypt`
(declarative copy-based dotfiles manager) + `pikr` (rofi replacement) era.

> If you are setting up a **second machine** that already tracks this repo, read
> **[Applying to another machine](#applying-to-another-machine)** BEFORE you
> `git pull` — a naive pull + Hyprland reload can blank your config.

Full blow-by-blow execution log (every command, every incident):
[`docs/superpowers/plans/2026-07-02-krypt-pikr-integration.md`](superpowers/plans/2026-07-02-krypt-pikr-integration.md).

---

## What changed

Merged 1026 upstream commits (merge base was 2024-08-06). Headline changes:

- **Menu system:** `rofi` → `pikr`. Hyprland binds + waybar `on-click` now call
  `krypt menu <name>` (e.g. `krypt menu apps|calc|wifi|power|…`), which run the
  `.menu-*` scripts (now pikr-backed) via `.krypt/commands.toml`.
- **Deploy manager:** GNU Stow (symlinks) → **krypt (copies + a manifest at
  `~/.local/state/krypt/manifest.json`)**. You now edit the repo then run
  `krypt link` / `krypt update` to deploy; edits are **no longer instantly
  live** the way stow symlinks were.
- **Config split:** `hyprland.conf` now `source=`s machine-local includes
  (`apps.conf`, `input.conf`, `monitors.conf`, `workspaces.conf`) seeded from
  `*.template.conf`; git identity moved to `~/.gitconfig.local` via `[include]`.

Local fixes made on top of the merge (all committed, so they reach every
machine):

| Commit    | Fix                                                                          |
| --------- | ---------------------------------------------------------------------------- |
| `b7c62cc` | `hyprland.conf`: `env = WGPU_BACKEND,gl` — GPU hang fix (see gotchas)        |
| `dc81bae` | `.krypt/links.toml`: gtk-4.0 glob → explicit file links (theme-symlink fix)  |
| `db08f7c` | reconcile `.claude/settings.json` (effort xhigh, ssh perm) + `opencode.json` |

---

## Shared vs machine-local files

**Machine-local — gitignored, NOT shared. Each machine has its own; safe to
differ:**

| File                             | Set by                                                 |
| -------------------------------- | ------------------------------------------------------ |
| `~/.config/hypr/monitors.conf`   | `nwg-displays` (per-hardware)                          |
| `~/.config/hypr/workspaces.conf` | `nwg-displays`                                         |
| `~/.config/hypr/apps.conf`       | `krypt setup --prompts hypr_apps`                      |
| `~/.config/hypr/input.conf`      | `krypt setup --prompts hypr_input`                     |
| `~/.config/hypr/hyprpaper.conf`  | template seed (wallpaper path)                         |
| `~/.gitconfig.local`             | `krypt setup --prompts git`                            |
| `~/.config/krypt/config.toml`    | krypt tool config (repo path) — untracked, per-machine |

**Shared — committed, WILL reach the other machine on `git pull`:** everything
else — the whole krypt/pikr layer, `hyprland.conf` (incl. `WGPU_BACKEND=gl`),
`.krypt/*.toml`, `waybar`, `fish`, `.claude/settings.json`, `opencode.json`,
`.codex/config.toml`, etc. Note `opencode.json` + `.codex/config.toml` carry
**this machine's** LLM endpoints (`137.175.76.24`, RunPod vLLM) and are shared —
adjust per machine if the endpoints differ, or they'll be identical everywhere.

---

## Applying to another machine

The other desktop is still on **stow + the old config**. A naive `git pull`
breaks it three ways: (1) `krypt`/`pikr` aren't installed → every menu bind
fails; (2) the new `hyprland.conf` `source=`s `apps.conf`/`input.conf` that
don't exist there yet → Hyprland auto-reload writes an **emergency STUB** over
`hyprland.conf`; (3) `.gitconfig` now needs `~/.gitconfig.local`.

Do it in this order (do **not** `hyprctl reload` until step 5):

1. **Install binaries**

   ```bash
   paru -S --needed krypt-bin pikr-bin
   # optional kryptic tools used by fish/tmux aliases:
   paru -S --needed hjkl-bin sqeel-bin buffr-bin hodl-bin inbx-bin gemini-cli
   ```

2. **Stash/commit local work** on that machine (`git -C ~/.files status` — clean
   it).

3. **Pull** — but do NOT trigger a Hyprland reload yet:

   ```bash
   git -C ~/.files pull
   ```

4. **Register the repo + seed machine-local files** (creates the `source=`
   includes so the reload in step 5 doesn't stub):

   ```bash
   mkdir -p ~/.config/krypt
   printf '[repo]\npath = "%s"\n' "$HOME/.files" > ~/.config/krypt/config.toml
   cd ~/.files
   krypt setup --prompts git,hypr_apps,hypr_input   # seeds ~/.gitconfig.local, apps.conf, input.conf
   cp -n .config/hypr/monitors.template.conf  ~/.config/hypr/monitors.conf
   cp -n .config/hypr/hyprpaper.template.conf ~/.config/hypr/hyprpaper.conf
   touch ~/.config/hypr/workspaces.conf
   # verify every source= target exists (must print nothing):
   for s in $(grep -oP '^source=\K.*' .config/hypr/hyprland.conf); do p="${s/#\~/$HOME}"; [ -e "$p" ] || echo "MISSING $p"; done
   ```

5. **Deploy with krypt + reload**

   ```bash
   krypt link            # first run adopts; if it SKIPS stow symlinks, see gotcha below
   hyprctl reload
   grep -q STUB ~/.config/hypr/hyprland.conf && echo "STUBBED — restore & investigate"
   krypt doctor          # expect all green except .gitconfig.local "drifted" (that's correct)
   ```

   Then take over any remaining stow **dir-symlinks** (see gotcha) and restart
   waybar so it picks up the new env:
   `pkill waybar; hyprctl dispatch exec waybar`.

6. **Display:** run `nwg-displays` on that machine for its own monitor layout.

7. **Verify:** `$mod+space`, `$mod+w`, and the waybar power/wifi buttons open
   pikr.

---

## Gotchas we hit (so you don't relearn them)

- **STOW HAZARD.** While a machine is still stow-deployed, the repo files ARE
  the live config (via `~/.config` symlinks). Editing/checking-out/stashing a
  tracked file mutates the live config; Hyprland auto-reloads `hyprland.conf`
  and, if it reads a half-written file or a missing `source=` include,
  **overwrites it with a stub** (`# This config is a STUB!`). Restore in place
  with `git show HEAD:<path> > <path>` (NOT `git checkout` — it lost the race),
  then `hyprctl reload`. Once on krypt (copies), this hazard is gone.

- **`krypt link --force` re-seeds `[[template]]` files.** `--force` (needed once
  to take over stow's symlinks) will **overwrite** `~/.gitconfig.local` and
  `~/.config/hypr/monitors.conf` with the bare templates — clobbering your
  identity and monitor layout. Prefer plain `krypt link`; if you must `--force`,
  re-seed those two afterward. Normal `krypt link`/`update` leave seeded files
  alone (krypt reports them as "drifted" — that is correct, not an error).

- **stow → krypt leaves dir-symlinks behind.** stow symlinks whole `~/.config/X`
  dirs; krypt writes its file-links _through_ them into the repo, so the dir
  stays a symlink (still edit-live). To fully convert: `rm ~/.config/X` (symlink
  only) for the krypt-managed dirs, then `krypt link` (no `--force`) recreates
  them as real copies. **Do NOT do this for dirs not in `links.toml`** (e.g.
  `qutebrowser`, `Vieb`) — you'll orphan them; leave those as symlinks or add
  `[[link]]` entries.

- **gtk-4.0 / theme symlinks.**
  `~/.config/gtk-4.0/{assets,gtk.css,gtk-dark.css}` are symlinks into the
  root-owned system theme (`/usr/share/themes/…`). A `**/*` glob makes krypt
  copy _through_ them → Permission denied. `links.toml` now lists only the real
  files (`colors.css`, `settings.ini`); the theme files stay
  theme/`nwg-look`-managed. `links.toml` has no `exclude` key.

- **GPU hang → `WGPU_BACKEND=gl` (the reason menus silently did nothing).** This
  machine is hybrid: **Intel i915 drives all outputs; NVIDIA MX550 on nouveau
  drives nothing.** pikr (and the other kryptic wgpu tools) default to the wgpu
  **Vulkan** backend, which _probes_ the nouveau GPU and hangs it in an
  uninterruptible **D-state** — the menu never renders, and the hung process
  then breaks the `pkill pikr` toggle so nothing opens afterward.
  `env = WGPU_BACKEND,gl` in `hyprland.conf` forces the GL/EGL backend on Intel
  and skips the Vulkan multi-GPU probe. GL is a safe universal fallback, so this
  line is harmless on single-GPU machines — but if the **other** desktop's dGPU
  is one you actually want wgpu apps to use, scope the var to pikr instead of
  setting it session-wide. Symptom recap: menu "does nothing"; check
  `ps -eo pid,stat,comm | grep pikr` for a **`D`** state and
  `hyprctl layers | grep pikr` for a stuck surface.

- **`krypt menu` needs the tool config.** Binds run from `$HOME`, so krypt can't
  find `.krypt.toml` in the cwd — it reads the repo path from
  `~/.config/krypt/config.toml` (`[repo] path = …`). Without it, every menu bind
  errors `read .krypt.toml: No such file or directory`.
