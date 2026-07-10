# Symlinked Claude Code Environments

**For:** Julius **Applies to:** the `.files` dotfiles repo (Arch + Fish, managed
by [krypt](https://github.com/kryptic-sh/krypt))

This is how I run **multiple Claude Code accounts on one machine** — each with
its own login, but all sharing a single set of settings, `CLAUDE.md`,
statusline, and skills that live (and are version-controlled) inside the
`.files` repo.

---

## The idea in one paragraph

Claude Code stores everything under one config directory. By default that is
`~/.claude`, but it honours the **`CLAUDE_CONFIG_DIR`** environment variable. So
"switch account" = "point `CLAUDE_CONFIG_DIR` at a different directory". Each
directory holds its **own** credentials, sessions, and history — but the files I
want identical everywhere (settings, global `CLAUDE.md`, statusline script,
skills) are **symlinks back into the `.files` repo**, so I edit them once,
commit once, and every account sees the change.

Three accounts here:

| Account  | Config dir       | How it's selected                      |
| -------- | ---------------- | -------------------------------------- |
| personal | `~/.claude`      | default — no env var                   |
| work     | `~/.claude-work` | `CLAUDE_CONFIG_DIR=$HOME/.claude-work` |
| derb     | `~/.claude-derb` | `CLAUDE_CONFIG_DIR=$HOME/.claude-derb` |

---

## What is shared vs. what is per-account

**Source of truth — lives in the repo at `.files/.claude/`:**

- `settings.json` — symlinked by **all three** dirs (see "The 2026-07-10 drift")
- `settings.local.json`
- `statusline-command.sh`
- `hooks/` — hook scripts (`edit_audit.py`, `notify-git-push.sh`);
  `~/.claude/hooks` is a symlink to this dir, and `settings.json` refers to them
  as `$HOME/.claude/hooks/…`
- `CLAUDE.md` → itself a symlink to `.files/.config/agents/AGENTS.md` (one
  AGENTS.md feeds Claude, Codex, and opencode)

**Shared skills — whole directory symlinked from `$HOME`:**

- `~/.agents` → `.files/.agents` (skills live in `.files/.agents/skills/`)

**Per-account — NEVER shared, each dir keeps its own:**

- `.credentials.json` — the account login (this is the whole point)
- `.claude.json` — per-account state
- `sessions/`, `history.jsonl`, `projects/`, caches, `plugins/`

So: log in three times (once per dir) → three accounts. Edit `settings.json`
once → all three change.

---

## Layout

```
~/.files/                         # the git repo (source of truth)
├── .claude/
│   ├── settings.json
│   ├── settings.local.json
│   ├── statusline-command.sh
│   ├── hooks/                    # edit_audit.py, notify-git-push.sh
│   └── CLAUDE.md          -> ../.config/agents/AGENTS.md
├── .config/agents/AGENTS.md      # the one global instruction file
└── .agents/skills/               # shared skills

~/.claude/                        # PERSONAL (real dir, default)
├── .credentials.json             # ← own login
├── settings.json         -> ~/.files/.claude/settings.json
├── settings.local.json   -> ../.files/.claude/settings.local.json
├── statusline-command.sh -> ../.files/.claude/statusline-command.sh
├── hooks                 -> ~/.files/.claude/hooks
└── CLAUDE.md             -> ../.files/.claude/CLAUDE.md

~/.claude-work/                   # WORK (this dir is itself versioned: -> .files/.claude-work)
├── .credentials.json             # ← own login
├── settings.json         -> ../.claude/settings.json   # relative INSIDE .files -> .files/.claude/
├── settings.local.json   -> ../.files/.claude/settings.local.json
├── statusline-command.sh -> ../.files/.claude/statusline-command.sh
└── CLAUDE.md             -> ../.files/.claude/CLAUDE.md

~/.claude-derb/                   # DERB (real dir)
├── .credentials.json             # ← own login
├── settings.json         -> ~/.files/.claude/settings.json
├── settings.local.json   -> .files/.claude/settings.local.json
├── CLAUDE.md             -> .files/.claude/CLAUDE.md
├── projects              -> ~/.claude/projects        # optional: share history
└── file-history          -> ~/.claude/file-history    # optional: share history

~/.agents -> .files/.agents       # shared skills, whole dir
```

> **`settings.json` is symlinked in every account dir.** It used to be optional
> ("keep a per-dir copy if an account needs different settings") — that option
> is retired, because taking it is what caused the drift below. Only
> `.credentials.json` and per-account state may differ. `settings.local.json` is
> shared here too.

---

## Fish switchers

Each account is a Fish function that sets `CLAUDE_CONFIG_DIR` for that
invocation only, then launches Claude. `--dangerously-skip-permissions` is baked
in — drop it if you want the prompts.

`.config/fish/functions/claude-work.fish`:

```fish
function claude-work --description 'Claude Code: work account, shared env'
    set -x CLAUDE_CONFIG_DIR $HOME/.claude-work
    command claude --dangerously-skip-permissions $argv
end
```

`.config/fish/functions/claude-derb.fish`:

```fish
function claude-derb --description 'Claude Code: derb account, shared env'
    set -x CLAUDE_CONFIG_DIR $HOME/.claude-derb
    command claude --dangerously-skip-permissions $argv
end
```

Plus in `config.fish`, `claude` = personal (default dir) and `cw` = work +
`--continue`:

```fish
function claude
    command claude --dangerously-skip-permissions $argv
end

# work account, resume last session (falls back to fresh)
function cw
    set -lx CLAUDE_CONFIG_DIR $HOME/.claude-work
    claude --continue $argv || claude
end
```

`set -x` inside a function scopes the var to that function call — it does
**not** leak into your shell, so `claude` (personal) and `claude-work` can run
in different terminals side by side.

---

## Set it up from scratch (do this, Julius)

Assumes you've already cloned your dotfiles to `~/.files` and Claude Code is
installed. Adjust names — you probably want e.g. `personal` + `work` instead of
`derb`.

### 1. Put the shared config in the repo

```fish
mkdir -p ~/.files/.claude
# move your existing real settings into the repo, or create fresh ones
mv ~/.claude/settings.json        ~/.files/.claude/settings.json
mv ~/.claude/settings.local.json  ~/.files/.claude/settings.local.json
mv ~/.claude/statusline-command.sh ~/.files/.claude/statusline-command.sh
# global instructions — one file for all agents
ln -s ../.config/agents/AGENTS.md ~/.files/.claude/CLAUDE.md
```

### 2. Wire the PERSONAL dir (default `~/.claude`) to the repo

```fish
ln -sf ../.files/.claude/settings.json         ~/.claude/settings.json
ln -sf ../.files/.claude/settings.local.json   ~/.claude/settings.local.json
ln -sf ../.files/.claude/statusline-command.sh ~/.claude/statusline-command.sh
ln -sf ../.files/.claude/CLAUDE.md             ~/.claude/CLAUDE.md
ln -sfn ~/.files/.claude/hooks                 ~/.claude/hooks
```

`settings.json` is **not** optional — link it. A copy is how the drift started.

### 3. Create a SECOND account dir (e.g. work)

```fish
mkdir -p ~/.claude-work
ln -sf ../.files/.claude/settings.json         ~/.claude-work/settings.json
ln -sf ../.files/.claude/settings.local.json   ~/.claude-work/settings.local.json
ln -sf ../.files/.claude/statusline-command.sh ~/.claude-work/statusline-command.sh
ln -sf ../.files/.claude/CLAUDE.md             ~/.claude-work/CLAUDE.md
```

(Optional — share command history/projects with personal instead of a blank
slate:)

```fish
ln -sf ~/.claude/projects     ~/.claude-work/projects
ln -sf ~/.claude/file-history ~/.claude-work/file-history
```

### 4. Share skills across every account

```fish
ln -s ~/.files/.agents ~/.agents      # skills live in .files/.agents/skills/
```

### 5. Add the Fish switcher

Drop a file into `~/.config/fish/functions/` — the name must match the function.
`~/.config/fish/functions/claude-work.fish`:

```fish
function claude-work --description 'Claude Code: work account, shared env'
    set -x CLAUDE_CONFIG_DIR $HOME/.claude-work
    command claude $argv
end
```

Fish autoloads it — new shells pick it up, or `source` the file to use it now.

### 6. Log in each account

The credentials are per-dir, so log in once per account:

```fish
claude          # personal — /login inside, pick your personal account
claude-work     # work     — /login inside, pick the work account
```

Each writes its own `~/.claude*/​.credentials.json`. Done.

---

## Verify

```fish
# each account dir resolves the shared files back into the repo:
readlink -f ~/.claude-work/CLAUDE.md
# → /home/you/.files/.config/agents/AGENTS.md

# each has its OWN credentials (different files, not links):
ls -l ~/.claude/.credentials.json ~/.claude-work/.credentials.json

# switching works:
claude-work            # runs under ~/.claude-work
env | grep CLAUDE      # nothing leaks in the outer shell afterwards
```

Inside Claude Code, `/status` shows the active account — confirm each launcher
lands on the right one.

---

## The 2026-07-10 drift

Three copies of `settings.json` had silently diverged, because this doc used to
offer "per-dir copy" as a supported option and `personal` + `derb` both took it:

| Dir               | Was                                   | Last written |
| ----------------- | ------------------------------------- | ------------ |
| `~/.claude`       | real file, uncommitted edits          | 2026-07-10   |
| `~/.claude-work`  | symlink into `.files`                 | —            |
| `~/.claude-derb`  | real file, stale copy                 | 2026-07-06   |
| `.files/.claude/` | the "source of truth" nobody wrote to | 2026-07-02   |

Nobody noticed because a copy keeps working — it just stops receiving changes.
The tracked copy was 8 days behind the running config; derb was 4 days behind
and still carried a hook that had been fixed elsewhere.

Reconciled by union merge into `.files/.claude/settings.json` (live scalars won;
entries only the tracked copy had were restored), then all three dirs symlinked
to it. The pre-merge `.bak` files were deleted once the merge was verified; the
tracked side is recoverable as `git show db08f7ce:.claude/settings.json`, and
the merge result is `c13c5e61`.

**Detect a recurrence in one command:**

```fish
for d in ~/.claude ~/.claude-work ~/.claude-derb
    test -L $d/settings.json; or echo "DRIFT: $d/settings.json is a real file"
end
```

Some apps save config by writing a temp file and renaming it over the target,
which **replaces a symlink with a regular file**. If a `/config` change ever
turns one of these back into a real file, re-link it and commit whatever the
live file gained.

## Gotchas

- **Symlinks vs. copies matter.** `CLAUDE_CONFIG_DIR` must point at a directory
  whose _shared_ files are symlinks into the repo. If you `cp` instead of `ln`,
  edits stop propagating and the accounts silently drift. This is not
  hypothetical — see "The 2026-07-10 drift" above.
- **Never symlink `.credentials.json` between accounts** — that defeats the
  point and both accounts fight over one token.
- **First run of a new dir is a blank Claude** — no login, no history. That's
  expected; run `/login`.
- **`git` won't track `~/.claude`** — only the `.files/.claude/` source is in
  the repo. The `~/.claude*` dirs are assembled by the `ln` commands above (or
  by krypt/stow if you wire them into your dotfile manager). On a fresh machine,
  re-run steps 2–4.
- **`--dangerously-skip-permissions`** in the wrappers means no permission
  prompts. Convenient, but it lets Claude run anything — omit it if you're not
  comfortable with that.
