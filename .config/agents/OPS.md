# Ops & Delegation Rules

General, repo-agnostic rules promoted from `crawly-mccrawlface/AGENTS.md` + its
runbooks — each one exists because the behaviour kept recurring. Per-repo files
may repeat these for non-configured tools; this copy is canonical **wording**
only — on conflict over a project's specifics, that project's own AGENTS.md wins
(workspace precedence rule).

## Delegation contract

Full contract: `crawly-mccrawlface/docs/runbooks/delegation.md`.
Non-negotiables:

- **Subagents are single-shot** — nothing resumes a returned subagent; a
  detached remote process notifies NO ONE, poll it.
- **Deliverable-gated completion** — in-flight terminal step = `INCOMPLETE`
  (`done`/`remaining`/`resume-cmd`), never a plain success.
- **Verify-before-trust** — a completion is a claim; the main thread verifies
  the artifact independently. "Watcher / notify-me-later" cited instead of the
  artifact = assume unfinished, take over.
- **No persistent-worker shape** — long tail beyond one turn → main thread owns
  the long step; delegate only bounded chunks.
- **State the contract in the delegation prompt** — deliverable + success check,
  single-shot, `INCOMPLETE` over false success. The prompt is a backstop; the
  artifact check is the gate.
- **Max 2 subagents in parallel** — house convention (defines the "max-2 rule"
  Plan Review references); batch larger fan-outs into waves of ≤2.

## Delegation economics

Delegate for **context preservation** (genuinely huge/unknown output, long
session), not as a blanket token-saver. Subagent cold-start billed ~15–20k tok
plus latency (measured Claude Code, crawly stack, 2026-07-02 — don't assume
elsewhere; detail in `crawly-mccrawlface/docs/runbooks/delegation.md`
§Appendix). Never delegate lint/format; tests optional, direct by default.
Dispatch tier: default mid; cheapest for mechanical work (logs, DB queries,
large/unknown reads); top only if requested or genuinely needed — standing
cases: the premise gate (round 1) and the FINAL review pass before something
ships or is built from (see AGENTS.md Plan Review). (The user-keyword "delegate"
rule — spawn cheaper-than-current — applies only to that explicit command.)

## Monitors & watchers

Anything that watches and reports state — CI pollers, background waiters,
remote-process/rented-instance monitors, DB/deploy waiters:

- **Fast-fail every poll** — detect failure each iteration; never wait out a
  timeout to "find out what happened".
- **Success is observed, never inferred** — absence of an error is not
  completion; on eventually-consistent/distributed checks (instance lists,
  replica status, k8s state) require ≥3 consecutive confirmations before
  declaring a terminal state — a single poll can lag. Report only observed
  evidence — never project an ETA.
- **Two layers** — monitor the item (process/log/status) AND the machine
  (cpu/ram/gpu/disk); a live process on an idle GPU is a failure.
- **Liveness checks must not match their own carrier** — trigger: your search
  pattern is a literal in the command running the search (wrapper
  `bash -c`/`ssh`/cron `sh -c`, heredoc, filename arg). The bracket form
  `[w]orker` is a `ps | grep` idiom and only a half-fix; one plain occurrence on
  a live carrier defeats it. The fix (anchor the match), its precision caveats,
  and the `comm`-reports-`MainThread`-on- node≥24 trap all live in the canonical
  statement — read it, don't restate it here:
  `crawly-mccrawlface/docs/runbooks/monitors.md` rule 5. Working form (copy,
  don't improvise): `ps -eo args | awk '$1 ~ /bin\/node$/ && /<pattern>/'` —
  anchor on the executable; arguments cannot impersonate it.
- **Parse structured data via stdin** — pipe API/JSON responses into a real
  parser; never string-interpolate a response into shell/python source (embedded
  quotes/control chars crash the parser and blind the monitor).
- **Every phase covered from creation**, per-phase timeouts, teardown in
  `trap`/`finally` and verified after.
- **Detectors ship `--test` self-tests**; expensive targets require an
  injected-failure dry run first.

This list is a subset — the full rule set (with the incident behind each rule)
is `crawly-mccrawlface/docs/runbooks/monitors.md`; metered-instance cost rules
in `docs/runbooks/on-demand-instances.md`.

## Shell honesty — no exit-code laundering

- `cmd | filter` reports the **filter's** exit code; a red `npm test` piped into
  `grep` reads as green. Success-critical commands run bare or under
  `set -o pipefail`; check the command's own status, never the filter's.
  Multiple red pushes shipped exactly this way.
- `set -euo pipefail` + `var=$(cmd | filter)` — a failing `cmd` aborts the
  caller silently; wrap tolerable failures in local `set +e +o pipefail`.
- `check && act` cannot block — the action fires on the exit code, not on a
  human reading the output. `git log @{u}..HEAD && git push` specifically; any
  verify-then-proceed generally. Run the check, read it, act as a separate
  command (crawly
  `docs/incidents/2026-08-09-review-converged-on-an-incomplete-spec.md` §6c).
- `cd` persists across an agent harness's shell calls — a later command inherits
  whatever directory an earlier call left. Anything backgrounded or detached
  uses absolute paths and re-`cd`s at the top of its own command; one launch
  went to the wrong directory and wrote its file into the wrong folder this way
  (crawly `docs/incidents/2026-08-06-en-parity-session-retrospective.md` §5).

## Push gating

Every push you manage — **including tag/release pushes that trigger CI/CD
deploys** — is gated by green lint + full test suite, verified by bare exit
codes. Red → fix first, re-run to green, then push. Docs-only pushes exempt from
the test gate; still format changed `.md`. If the repo has no lint/test tooling
configured, state that explicitly to the user (chat reply, commit body, or PR
description) — don't fabricate a gate and don't skip silently.

Verify the pushed RANGE, not just the tip: `git log --oneline @{u}..HEAD` before
every push. The local branch can carry unreviewed commits from another session,
and a push ships them all — two went out exactly this way on 2026-08-05 (crawly
EN-parity retrospective §5).

## Destructive ops & data safety

- Any destructive/`--apply` job gets one **live dry-run against real data**
  before first production use — mocked tests cannot catch driver-shape
  mismatches (one silent no-op survived 5 spec-review rounds + 3 code reviews
  because every reviewer reasoned over the mock).
- Never add row/size caps that fail a job or drop data when volume exceeds a
  threshold — packet/OOM limits are a **batching** problem (chunk the writes so
  every row persists); volume anomalies are caught by observability, not by
  failing the job.

Source: `crawly-mccrawlface/AGENTS.md` §Testing, §Gotchas.

## Tooling hooks

- A post-edit format hook (Claude Code's `PostToolUse` on `Write|Edit`; other
  tools: check for the equivalent) rewrites the file after your edit lands. A
  follow-up `Edit` whose `old_string` reproduces text you just wrote will then
  miss — the hook reformatted it. Read the file before that second edit.
  ("Prettier corrupts Unicode" is a retired myth — byte-for-byte tested
  2026-07-10; do NOT `sed -i` around a formatter that is not misbehaving.)
- Multiple hook commands under one matcher **run in parallel** ("All matching
  hooks run in parallel", Claude Code hooks doc). Two of them writing the same
  file is a lost-update race. One writer per file: if your eslint config extends
  `eslint-plugin-prettier/recommended`, `eslint --fix` already applies prettier
  — do not also run prettier.
- Never end a hook command with `2>/dev/null || true`. It buries formatter
  crashes, missing binaries and unfixable lint errors. Let a non-zero status
  surface (`exit 2` shows stderr to the agent).
- Hooks are not path-scoped by default; a `Write|Edit` hook fires on scratchpad
  and out-of-tree files too. Gate on `$CLAUDE_PROJECT_DIR` — and bail when it is
  unset, or the `"$DIR"/*` glob matches every absolute path.

## Cross-repo MySQL scars

- Unaliased `information_schema` columns come back **UPPERCASE** from the
  driver; a lowercase-keyed mock passes green while prod resolves `undefined`.
  Alias in SQL (`AS table_name`) + read defensively
  (`row.table_name ?? row.TABLE_NAME`). Hit twice, two repos.
- Resolving strings to ids via a pre-fetched name→id map against a `*_ci` /
  `*_ai_ci` UNIQUE column: normalize BOTH sides first, or resolve per-row with
  `WHERE name = ?` (rides the column collation). An exact-match map keyed on raw
  input silently misses every casing/accent variant — `rsty-tweekin` dropped
  48.8% of its edges this way (2026-07-08).
- MySQL rejects `LIMIT` inside `IN`/`ALL`/`ANY`/`SOME` subqueries — use a `JOIN`
  on a derived table.
- systemd MySQL `LimitNOFILE` defaults to 10,000 → `table_open_cache`
  thrashing + semaphore-timeout crashes under load on shared DB hosts; fix is a
  drop-in raising it (e.g. `LimitNOFILE=200000`) + daemon-reload + restart.

Source: `crawly-mccrawlface/AGENTS.md` §Gotchas; memories
`gotcha-information-schema-uppercase-keys`,
`gotcha-tweekin-case-lookup-vs-ai-ci-collation`.
