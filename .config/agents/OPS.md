# Ops & Delegation Rules

General, repo-agnostic rules promoted from `crawly-mccrawlface/AGENTS.md` + its
runbooks — each one exists because the behaviour kept recurring. Per-repo files
may repeat these for non-configured tools; this copy is canonical **wording**
only — on conflict over a project's specifics, that project's own AGENTS.md wins
(workspace precedence rule).

## Delegation contract

Full contract: `crawly-mccrawlface/docs/runbooks/delegation.md`.
Non-negotiables:

- **Subagents are single-shot** — nothing resumes a returned subagent;
  completion notifications go to the main thread only. A detached remote process
  (`setsid`/`nohup` + log file) notifies NO ONE — the only way to know it
  finished is to poll it. "I'll auto-resume when the watcher fires" is
  structurally impossible for a subagent.
- **Deliverable-gated completion** — a subagent reports success only when the
  concrete artifact is verified present; an in-flight terminal step is
  `INCOMPLETE` (`done`/`remaining`/`resume-cmd`), never a plain success.
- **Verify-before-trust** — a subagent's completion is a claim; the main thread
  verifies the artifact independently. A final message citing a "watcher /
  notify-me-later" instead of the artifact = assume unfinished, take over.
  Repeated false-complete → take the work over; don't re-delegate the same
  shape.
- **No persistent-worker shape** — long tail beyond one turn → main thread owns
  the long step (harness-tracked background + monitor) and delegates only
  bounded chunks.
- **State the contract in the delegation prompt** — every long/remote delegation
  names the concrete deliverable + its success check, and says explicitly:
  detached remote processes notify no one, you own the poll loop until the
  artifact exists; you are single-shot, return `INCOMPLETE` if you can't finish,
  never a plain success. The prompt is a backstop — the artifact check
  (verify-before-trust) is the gate.
- **Max 2 subagents in parallel** — house convention, not from the runbook above
  (this defines the "max-2 rule" the Plan Review contract references); batch
  larger fan-outs into waves of ≤2.

## Delegation economics

Delegate for **context preservation** (genuinely huge/unknown output, long
session), not as a blanket token-saver — output filters (rtk tee hook) are the
primary saver. Subagent cold-start bills ~15–20k tok before doing anything, plus
latency (spawn + ≥2 model turns). Never delegate lint/format (the returned
summary alone outweighs filtered output); tests optional, direct by default.
Magnitudes were measured on crawly's Node/eslint/jest stack (2026-07-02) —
spot-check filtered-output size before assuming the same ratios on another
stack. Dispatch tier: default mid-tier; cheapest for mechanical work (log reads,
DB queries, large/unknown reads); top tier only if requested or genuinely
needed. (The user-keyword "delegate" rule in AGENTS.md — spawn
cheaper-than-current — applies only to that explicit command.)

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
- **Bracket-pgrep** — `pgrep -f "[w]orker"`; plain `-f` self-matches the command
  carrying it.
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

## Push gating

Every push you manage — **including tag/release pushes that trigger CI/CD
deploys** — is gated by green lint + full test suite, verified by bare exit
codes. Red → fix first, re-run to green, then push. Docs-only pushes exempt from
the test gate; still format changed `.md`. If the repo has no lint/test tooling
configured, state that explicitly to the user (chat reply, commit body, or PR
description) — don't fabricate a gate and don't skip silently.

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

- Claude Code's PostToolUse prettier-on-edit hook can corrupt files near Unicode
  (other tools: check for an equivalent post-edit format hook) — for targeted
  replacements adjacent to Unicode, use `sed -i` via shell (GNU sed; no `''`
  backup arg — that's BSD/macOS) instead of the Edit tool.

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
