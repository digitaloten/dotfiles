# Claude edit-audit log

Forensic trace of every file mutation Claude makes, and of anything that
rewrites that file afterwards. Built 2026-07-10 after a post-edit prettier hook
was found silently reformatting files between a `Write` and the next `Edit`,
which made the `Edit` fail with `String to replace not found in file` and got
misdiagnosed for months as "prettier corrupts files near Unicode".

## Where it lives

| Thing            | Path                                                                     |
| ---------------- | ------------------------------------------------------------------------ |
| Log root         | `~/.local/state/claude/edit-audit/` (override: `$CLAUDE_EDIT_AUDIT_DIR`) |
| Event stream     | `<root>/events.jsonl` (rotates at 16 MB, keeps `.1`–`.3`)                |
| Mangle artifacts | `<root>/mangled/<date>/<ts>-<tool_use_id>/`                              |
| In-flight state  | `<root>/pending/` (drained on next tool call; 6 h TTL)                   |
| Hook script      | `~/.claude/hooks/edit_audit.py`                                          |

Deliberately **outside every git repo** — the log records edits to repos, so it
must not be an edit to a repo.

## How it decides something was mangled

It never diffs against a snapshot taken after the fact, because post-edit hooks
run **in parallel** with each other and racing them is unreliable. Instead it
computes what Claude _intended_ to be on disk, from the tool call itself:

- `Write` hands the hook the full `content`.
- `Edit` hands it `old_string` / `new_string` / `replace_all`, which are applied
  to the pre-edit bytes by the hook, mirroring the Edit tool's own match rules
  (unique match required unless `replace_all`).

Resolution is deferred to the **next `PreToolUse` (any tool) or to `Stop`**. By
then Claude Code has run every `PostToolUse` hook to completion, so the file has
settled. Nothing polls or sleeps.

## Statuses

| `status`                    | Meaning                                                                                                           |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `clean`                     | On-disk bytes == what Claude intended. Nothing touched it.                                                        |
| `MANGLED`                   | On-disk bytes differ from intent, and differ from pre-edit. A hook or external writer rewrote it. Artifact saved. |
| `tool_not_applied`          | On-disk bytes == pre-edit bytes. Tool was denied, interrupted, or errored. **Not** mangling.                      |
| `unverifiable`              | Intent could not be computed (binary, oversized, `MultiEdit`).                                                    |
| `file_absent_or_unreadable` | Gone, too large (>2 MB), or unreadable at resolve time.                                                           |

`intent_note` explains any `unverifiable`: `old-string-absent`,
`old-string-ambiguous`, `binary-file`, `pre-too-large`, `pre-absent`,
`intent-not-modelled:<tool>`.

## Events

- `intent` — a Write/Edit is about to run; records `pre_sha`, `intent_sha`.
- `resolve` — the verdict above, with `final_sha` and, on `MANGLED`, `artifact`.
- `tool_failure` — from `PostToolUseFailure`. Records the `error`, whether
  `old_string` is still present on disk (`old_string_present_now`), and
  `prior_mangle_of_this_file` — the earlier `MANGLED` event in the same session
  that is almost always the cause. **This correlation is the whole point.**

## Queries

```bash
R=~/.local/state/claude/edit-audit

# Everything that got mangled, newest last
jq -c 'select(.status=="MANGLED") | {ts, file, artifact}' "$R/events.jsonl"

# Edit failures, and what mangled the file beforehand
jq -c 'select(.event=="tool_failure") |
       {ts, file, error, still_matches: .old_string_present_now,
        caused_by: .prior_mangle_of_this_file.ts}' "$R/events.jsonl"

# Status tally
jq -r '.status // .event' "$R/events.jsonl" | sort | uniq -c | sort -rn

# Read the most recent mangle
cat "$(ls -dt "$R"/mangled/*/*/ | head -1)/mangle.diff"

# Which files get rewritten most (i.e. which formatter hook to fix)
jq -r 'select(.status=="MANGLED") | .file' "$R/events.jsonl" | sort | uniq -c | sort -rn
```

## Safety properties

- **Never breaks the tool call it observes.** Every path is wrapped; malformed
  stdin, unreadable files, and full disks all exit `0`.
- **Bounded on disk.** Files >2 MB are not snapshotted; `events.jsonl` rotates
  at 16 MB; `mangled/` is pruned to the newest 300 directories; artifacts are
  skipped entirely when free space drops below 1 GB.
- **No secrets beyond what Claude already read.** Artifacts contain file content
  Claude was already handling. `old_string_head` is truncated to 200 chars.

## Registration

`~/.claude/settings.json`:

```json
"PreToolUse":         [{ "matcher": "*",                              "hooks": [{ "type": "command", "command": "python3 \"$HOME/.claude/hooks/edit_audit.py\" pre",  "timeout": 15 }] }],
"PostToolUseFailure": [{ "matcher": "Write|Edit|MultiEdit|NotebookEdit", "hooks": [{ "type": "command", "command": "python3 \"$HOME/.claude/hooks/edit_audit.py\" fail", "timeout": 15 }] }],
"Stop":               [{                                              "hooks": [{ "type": "command", "command": "python3 \"$HOME/.claude/hooks/edit_audit.py\" stop", "timeout": 15 }] }]
```

`"*"`, `""`, and an omitted `matcher` all mean "match all" (Claude Code hooks
reference). `PostToolUseFailure` is a distinct event from `PostToolUse` — the
latter fires only on success, which is why Edit failures were previously
invisible to hooks.

## Caveat: `~/.claude` is not symlinked to this repo

`~/.claude/settings.json` and `.files/.claude/settings.json` are independent
files and have drifted. The live one is what Claude Code reads. Copies here are
backups, not a stow target — reconcile by hand before assuming either is
current.
