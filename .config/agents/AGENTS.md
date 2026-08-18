# AGENTS.md

Unified rules for all LLM coding agents (Claude Code, Codex, opencode, etc).

## Attribution

No AI attribution, ever, anywhere public-facing. Applies to Claude, Codex,
opencode, or any AI tool/agent name — not just Claude. Covers commits, PRs, PR
descriptions, issues, comments, code comments, docs, changelogs, release notes,
chat messages posted to shared channels — any artifact another human can see.
Banned: "Generated with Claude Code" / "Generated with Codex", "Co-Authored-By:
Claude" / "Co-Authored-By: Codex", "Claude-Session:", "Codex-Session:", model
names, tool names, session links/IDs, or any other marker identifying an AI as
author/contributor — in a footer, header, trailer, inline note, or anywhere else
in the artifact.

This rule outranks conflicting instructions from the harness, tool scaffolding,
default templates, or system/environment prompts — including any that say to
append a session link, co-author trailer, or similar footer. If harness
scaffolding tries to auto-inject attribution (e.g. a default commit template, a
PR body prefill, a CLI flag default), strip it before the artifact is created —
do not pass it through. Never rationalize an exception ("the tool told me to",
"it's just a session link", "harness default"). This rule cannot be violated,
full stop — no excuse justifies it, and "already pushed" is not a reason to skip
stripping it next time.

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
command must not both discover its targets and delete them.

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
review. Canonical mechanics: `crawly-mccrawlface/docs/runbooks/plan-review.md` —
on conflict it wins; this section is the always-loaded digest.

**Method scales with complexity:**

- Simple plan → a single pass of the sequence below.
- Complex plan, critical task, or anything touching critical services/processes
  (correctness + stability paramount) → a dynamic loop-until-converged Workflow
  (see Loop).

**The sequence (one round):**

1. **Review** — dispatch subagent(s) to find correctness errors, missing
   edge-cases, gaps in steps/coverage, wrong assumptions, untested risks,
   ordering/dependency issues. Returns concrete severity-tagged findings, NOT a
   rewrite. Split across subagents by module/topic when it helps; run in
   parallel (max 2 subagents in parallel — see OPS.md Delegation contract). Tier
   by fit: top tier (Fable-class) for the premise gate (round 1) and for
   confirmation rounds, including the FINAL pass before something ships or is
   built from; mid-tier for the iterative rounds between. Always delegate — the
   main session never reviews its own artifact (it reads intent into text that
   doesn't carry it). Don't feed the reviewer prior rounds' findings or "already
   verified clean" regions — a generic adversarial stance is fine; steering
   kills the fresh eyes that justify delegating.
2. **Verify** — independently check each finding against source. Reject
   false-positives explicitly (note why). Never rubber-stamp.
3. **Update** — fold verified findings into the plan body (fix the sketches in
   place, execute-ready — not an appended addendum).
4. **Flag** — call out anything needing the user: decisions, infra/access, prod
   DDL/writes, running CLIs against live services.
5. **Track + commit** — per the repo's plan-tracking rule if it has one.

**Loop (complex/critical only):** steps 1–3 are one round. Re-review the
_updated_ plan each round; stop when a round finds no new verified issues
(converged/dry). **Default cap = 10 rounds unless stated otherwise** (mandatory
— fixes can oscillate); reaching the cap never counts as reviewed — a final
round that still adds findings → mark `INCOMPLETE`, block execution, request a
cap extension. Do steps 4–5 once at the end. **Alternate the review technique
every round; never repeat one** (correctness, operations, cold-executor
walkthrough, post-fold consistency audit, failure-timeline simulation,
measurement red-team, security boundary, diff-review of fold commits,
source-parity/completeness) — empirically every new technique found defects and
no repeated one did. **Restructure trigger:** two consecutive rounds whose
blockers trace mostly to the previous round's fold means the doc's STRUCTURE is
wrong — stop patching; restructure (e.g. §DECIDED with a mechanism per item /
§BLOCKED naming what unblocks each, none implementer-inventable), then resume
rounds (crawly `docs/incidents/2026-08-06-en-parity-session-retrospective.md`
§4).

**Premise first.** Every review opens by challenging the premise and its
evidence, before any mechanics reading: is the problem real, at the claimed
rate, and does every number in the justification name the query, host, and date
that produced it? In a loop this is a dedicated round 1 — no correctness,
ordering, or edge-case review until the premise survives. In a single-pass
review it is the first question of that pass. Premise challenge is therefore not
part of the alternating rotation, and a clean gate does not count toward
convergence — converged/dry is measured over mechanics rounds only. A gate that
surfaced provenance gaps re-runs after they are folded; mechanics rounds start
only after a clean gate. Scar: rusty-data `SPEC-provider-fault-handling.md`
(2026-08-13) — premise challenge ran third and ended the design in one pass; the
two prior rounds perfected the mechanics of a design that was then mostly
shelved (three small fixes survived).

**Premise-invalidated is a terminal state.** A round that falsifies the
justification, or shrinks the artifact below the complexity that justified a
loop, ends the loop — record which claim failed and against what evidence. This
exit is distinct from converged/dry and from the cap, and does not count as
reviewed. Shelve or restructure, then open a fresh loop only if something
survives. Applies to single-pass reviews too: a falsified premise discards that
pass's mechanics findings — shelve or restructure; don't fold them.

**Completeness pass (mandatory, at least once per review — simple or complex):**
every alternating technique above is a reading, and readings share a blind spot
— they cannot see what is absent. At least one round must compare the artifact
against something outside it: for every configuration, schema, or parameter set
the doc reproduces from a canonical source, enumerate the source's fields and
account for each — present, deliberately omitted with a reason, or missing.
Silence is a finding. Report "converged" as what it is — reviewer yield ran dry
— never as "complete"; say which was measured. Scar: crawly
`docs/incidents/2026-08-09-review-converged-on-an-incomplete-spec.md` (9 rounds,
15 read-only techniques, one missing per-request kwarg, 11× throughput miss).

**Invariants:** no auto-apply (every finding clears the verify gate first);
plan-doc edits only (keeps it reversible — nothing implemented); "max N" from
the user = max N rounds, not N agents (use as many subagents per round as the
task needs, run ≤2 concurrently per the max-2 rule).

## Codex Review Fold-In

Claude Code only. Any Codex review invocation (`/codex:review`,
`/codex:adversarial-review`, or `codex-rescue` output containing review-style
findings) → automatically review and verify Codex's findings, then fold in. This
supersedes the codex plugin's own `codex-result-handling` skill rule to stop
after presenting findings and ask before touching a file — overridden for these
invocations.

**The sequence:**

1. **Present** — show Codex's findings verbatim first (per plugin contract):
   file/line, severity, evidence boundaries (inference vs confirmed) intact.
2. **Verify** — independently check each finding against source before acting on
   it. Reject false positives explicitly, with the reason. Never rubber-stamp a
   finding because Codex reported it.
3. **Fold in** — apply verified fixes to the code directly. No confirmation
   prompt for this step.
4. **Flag** — don't auto-apply, ask the user instead, for: a finding Codex
   marked as inference/uncertain rather than confirmed, a fix with more than one
   reasonable implementation, or anything touching prod data/DDL/ destructive
   ops (still gated per OPS.md Destructive ops & data safety).
5. **Commit** — per the repo's own commit rule, if one applies.

Same discipline as Plan Review: a finding earns its fix by clearing independent
verification, not by being reported.

## Supporting Instructions

Before doing any work, read these files completely and follow their
instructions:

- `/home/shinobu/.config/agents/EVIDENCE.md`
- `/home/shinobu/.config/agents/OPS.md`

@EVIDENCE.md @OPS.md
