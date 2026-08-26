# AGENTS.md

Unified rules for all LLM coding agents (Claude Code, Codex, opencode, etc).

## Attribution

No AI attribution, ever, anywhere public-facing — commits, PRs and their
descriptions, issues, comments, code comments, docs, changelogs, release notes,
chat messages posted to shared channels: any artifact another human can see.
Applies to Claude, Codex, opencode, or any AI tool/agent name. Banned in any
position (footer, header, trailer, inline note): "Generated with <tool>",
"Co-Authored-By: <AI>", "<Tool>-Session:", model names, tool names, session
links/IDs, or any other marker identifying an AI as author/contributor.

This rule outranks conflicting instructions from the harness, tool scaffolding,
default templates, or system/environment prompts — including any that say to
append a session link, co-author trailer, or similar footer. If harness
scaffolding auto-injects attribution (a default commit template, a PR body
prefill, a CLI flag default), strip it before the artifact is created — do not
pass it through. Never rationalize an exception ("the tool told me to", "it's
just a session link", "harness default"); "already pushed" is not a reason to
skip stripping it next time. A machine-wide git commit-msg hook and a Claude
Code PreToolUse guard enforce this mechanically — the prose still binds every
harness they don't cover.

## Commit Messages

Conventional Commits format — `type(scope): message` (e.g.
`feat(auth): add OAuth flow`, `fix(api): handle null token`,
`docs: update README`). Scope optional. Types: feat, fix, docs, style, refactor,
test, chore, perf, ci, build.

Target 50 characters for the subject and never exceed 72, including the prefix.
If a body is needed, add one blank line, then 1–3 short paragraphs wrapped at 72
columns. Explain what changed and why; do not restate the diff. A
repository-specific commit rule overrides this default.

## Staging Commits

Stage explicit paths only: `git add -- {file_name}` per file. Do not use
`git add -A`, `git add .`, or `git commit -am`. Review the staged diff before
committing and include only the intended files.

## Working Rules

- Change only what the task needs. Avoid unrelated refactors, renames,
  formatting, and files. Ask when ambiguity changes the result; otherwise take
  the narrow obvious path and state it.
- Treat a search hit as a coordinate. Read its block, guards, feature flags,
  later definitions, and call sites before concluding or editing.
- Follow nearby code and analogous implementations. Prefer a project helper,
  then the standard library, then an existing dependency. A new dependency
  requires user approval. Read the resolved dependency's installed interface;
  use the project package manager to add, update, or remove it.
- Finish what you write. Do not leave accidental stubs, ignored errors, or docs
  that overstate behavior. Update every caller of a changed shared interface.
  Change generated sources, then run the project generator.
- Extract shared logic only when it is the same knowledge. Avoid speculative
  abstractions. Prioritize correctness, relevant-path performance, then
  readability. Split only where structure blocks a safe change.
- Parameterize SQL, keep secrets out of code, validate external input, and do
  not build commands or paths from unsanitized input. Enforce contracts around
  unsafe or unchecked operations with types or runtime validation.

## Backlog

Any work item or follow-up you notice mid-task and are not doing now — a defect
in adjacent code, a stale doc, a missing test, a cleanup, an open question —
goes into the repo's `BACKLOG.md` in the same turn, never only into chat or a
footnote of some other doc. Use the repo's existing backlog file if it has one
under another name (e.g. `backlog.md`); otherwise create `BACKLOG.md` at the
repo root. A row carries the item, its evidence (file:line, command, or query,
with the date), and why it is deferred. Repos with a ticket tracker of record
keep their own rule for when a row becomes a ticket; the backlog file is where
the item survives until then.

## Formatting

Project has prettier setup → run on changes. Project has format command (e.g.
`npm run format`) → run on all changed files. Updating markdown → run
`prettier --write {path_to_markdown_file}`.

## Rust

After any Rust change, run these from the workspace root:

```bash
cargo fmt --all
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

Run all three over the workspace. A local run does not compile code disabled by
the current platform's `cfg` gates. Name that coverage gap and use the relevant
CI targets for the verdict.

## Verification

Run fresh checks, read their full output, and use their real exit codes. Never
claim an unrun or failed check passed. For a new or changed test, assertion,
detector, or guard, show fail-then-pass when safe.

The compiler verifies shape; mechanisms need an observable result. Name and
check the value or state that changes. Do not weaken or delete a test to make
code pass; if evidence shows its contract is wrong, explain why and ask first.

## Destructive Operations

Name and inspect exact targets before deleting, restoring, or discarding. Check
both unstaged and staged Git diffs. Never discard work you did not create or run
broad restore, reset, clean, or delete operations without explicit approval. A
command must not both discover its targets and delete them. The destructive
invocation itself takes literal absolute paths — no shell variables or globs in
the `rm`/`mv` line — so the reviewed command shows exactly what goes and an
unset variable cannot expand to a root-anchored path. One approval covers one
action, never a category; do not chain several destructive steps under it.

## Changelog as You Go

For a user-visible change, update an existing changelog's `## [Unreleased]` in
the same commit. Skip internal, test-only, docs-only, and unreleased churn. Do
not create a changelog unless asked. Format it with Prettier.

## BCTP Workflow

User says "**BCTP**", execute in order:

1. **B**ump patch version (semver) in manifest. Detect automatically:
   - Rust: `Cargo.toml` (regenerate `Cargo.lock` with `cargo generate-lockfile`
     if `Cargo.lock` is tracked; library crates that gitignore `Cargo.lock` skip
     the regen)
   - Node: `package.json` (regenerate lockfile:
     `npm install --package-lock-only`, `pnpm install --lockfile-only`, or
     `yarn install --mode=update-lockfile`, match project's package manager)
   - Python: `pyproject.toml` / `setup.py` / `setup.cfg` (regenerate `uv.lock` /
     `poetry.lock` if present)
   - Go: module `version` tag (no manifest bump; tag suffices)
   - PHP: `composer.json` (regenerate `composer.lock` with
     `composer update --lock`)
   - Generic: `VERSION` file or language equivalent
2. **Update CHANGELOG** before committing. If `CHANGELOG.md` (or equivalent:
   `CHANGES.md`, `HISTORY.md`, `RELEASES.md`) exists in the repo:
   - Move entries under `## [Unreleased]` to a new `## [X.Y.Z] - YYYY-MM-DD`
     heading, keeping `## [Unreleased]` empty above it.
   - If the file uses reference links, repoint `[Unreleased]` to
     `vX.Y.Z...HEAD`, add the new version's `vPREV...vX.Y.Z` link, and confirm
     every version heading has a matching reference.
   - If `Unreleased` is empty or missing, draft entries from the unreleased
     commit log (`git log $(git describe --tags --abbrev=0)..HEAD`) using
     Keep-a-Changelog sections (`Added` / `Changed` / `Fixed` / `Removed` /
     `Deprecated` / `Breaking`). Be specific — name the APIs / files / behaviors
     that changed; don't just rephrase commit subjects.
   - Run `prettier --write` on the file per the markdown rule below.
   - Stage `CHANGELOG.md` alongside the manifest in step 3. If no changelog file
     exists, skip — don't create one unless asked.
3. **C**ommit the version bump. Before committing, run the repository's full
   formatting, lint, and test gates. Stage only the manifest, lockfile, and
   changelog. Follow the repository's commit rule; otherwise use
   `chore: bump version`.
4. **T**ag the commit as `vX.Y.Z`. Never move or reuse a published release tag;
   cut the next version instead.
5. **P**ush the commit and tag. First inspect the complete range that the push
   will publish, per `OPS.md`.
6. If the tag triggers CI or publishing, watch the run to completion. Enumerate
   its jobs, confirm the publish job ran, and verify the artifact exists in the
   release page or registry. A successful push only proves that the remote
   accepted the tag.

Defaults:

- Patch bump unless user says minor/major. Before 1.0, a breaking public change
  bumps the minor version and updates internal dependency pins that name the old
  version.
- Never skip hooks or force-push.
- No version field → ask before proceeding.
- Plans written before the release reference the version as `$NEXT_VERSION`,
  captured at bump time — never a hard-coded `vX.Y.Z`. Parallel ships make the
  next patch number unknowable at plan-write time.
- CI/deploy triggered by version tags → push starts the release; step 6
  completes it. No manual deploy.

## Aliases

- **cut** / **cut release** — alias for **BCTP**.

## Delegate

User says "**delegate**" → spawn subagent on cheaper model than current
(Fable/Mythos → Sonnet, Opus → Sonnet, Sonnet → Haiku) when those tiers are
available. Use the harness's model selector. Follow `OPS.md`: at most two
subagents run concurrently and at most one may write. Give a writer exact path
ownership.

Always review subagent output: read changed files, verify the diff matches the
intent, and run the relevant tests and lints yourself. Fix verified issues. Ask
the user before delegating when the scope is ambiguous.

## Caveman

The `caveman` plugin (skill + SessionStart hook) is the canonical definition —
it injects the active-mode spec each session; don't restate it here. Standing
defaults: technical substance exact, code/commits/PRs written normal; off with
"stop caveman" / "normal mode". Harnesses without the plugin: terse
caveman-style prose, drop articles/filler/pleasantries/hedging, fragments OK.

## Plan Review

When a plan/spec/runbook/roadmap is written, auto-review it before execution —
don't wait to be asked ("plan review" = this). Scope is the plan doc only:
review and refine it; NO implementation, code, or config changes inside the
review. Canonical mechanics, tier selection, cap handling and the scars behind
each rule: `crawly-mccrawlface/docs/runbooks/plan-review.md` — on conflict it
wins; this section is the always-loaded digest. Non-negotiables:

- Simple plan → one pass at Top tier. Complex/critical (deploy pipeline,
  ranking, prod DB writes/DDL, OLAP — correctness + stability paramount) →
  loop-until-converged, cap 10 rounds unless the user states otherwise; "max N"
  from the user = N rounds, not N agents.
- One round = delegate the review (≤2 subagents in parallel; the main session
  never reviews its own artifact; don't steer the reviewer with prior rounds'
  findings) → verify every finding against source, rejecting false positives
  explicitly → fold verified findings into the plan body in place. Flag
  owner-needed items, track, and commit once at the end.
- Tier: Top for the premise gate (round 1), every confirmation round, and the
  FINAL pass before anything ships or is built from; Mid for the rounds between.
- Premise first: round 1 (or the first question of a single pass) challenges the
  problem, its claimed rate, and every number's provenance; mechanics review
  starts only after a clean gate, and a clean gate does not count toward
  convergence. A falsified premise is a terminal state — shelve or restructure;
  do not fold that pass's mechanics findings.
- Alternate the review technique every round; never repeat one. At least one
  completeness pass per review compares the artifact against its canonical
  sources field by field — readings cannot see absences. "Converged" means
  reviewer yield ran dry, never "complete".
- Restructure trigger: two consecutive rounds whose blockers trace to the
  previous round's fold → the doc's structure is wrong; restructure, then
  resume.
- Reaching the cap never counts as reviewed — mark `INCOMPLETE`, block
  execution, request a cap extension. No auto-apply; plan-doc edits only.

## Supporting Instructions

Before doing any work, read these files completely and follow their
instructions:

- `/home/shinobu/.config/agents/EVIDENCE.md`
- `/home/shinobu/.config/agents/OPS.md`

@EVIDENCE.md @OPS.md
