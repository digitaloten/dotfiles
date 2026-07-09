# Ops & Delegation Rules

General, repo-agnostic rules promoted from `crawly-mccrawlface/AGENTS.md` + its
runbooks — each one exists because the behaviour kept recurring. Per-repo files
may repeat these for non-configured tools; this copy is canonical.

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

## Delegation economics

Delegate for **context preservation** (genuinely huge/unknown output, long
session), not as a blanket token-saver — output filters (rtk tee hook) are the
primary saver. Subagent cold-start bills ~15–20k tok before doing anything.
Never delegate lint/format (the returned summary alone outweighs filtered
output); tests optional, direct by default.

## Monitors & watchers

Anything that watches and reports state — CI pollers, background waiters,
remote-process/rented-instance monitors, DB/deploy waiters:

- **Fast-fail every poll** — detect failure each iteration; never wait out a
  timeout to "find out what happened".
- **Two layers** — monitor the item (process/log/status) AND the machine
  (cpu/ram/gpu/disk); a live process on an idle GPU is a failure.
- **Bracket-pgrep** — `pgrep -f "[w]orker"`; plain `-f` self-matches the command
  carrying it.
- **Every phase covered from creation**, per-phase timeouts, teardown in
  `trap`/`finally` and verified after.
- **Detectors ship `--test` self-tests**; expensive targets require an
  injected-failure dry run first.

Detail + metered-instance cost rules:
`crawly-mccrawlface/docs/runbooks/monitors.md`,
`docs/runbooks/on-demand-instances.md`.

## Shell honesty — no exit-code laundering

- `cmd | filter` reports the **filter's** exit code; a red `npm test` piped into
  `grep` reads as green. Success-critical commands run bare or under
  `set -o pipefail`; check the command's own status, never the filter's.
  Multiple red pushes shipped exactly this way.
- `set -euo pipefail` + `var=$(cmd | filter)` — a failing `cmd` aborts the
  caller silently; wrap tolerable failures in local `set +e +o pipefail`.

## Push gating

Every push you manage is gated by green lint + full test suite, verified by bare
exit codes. Red → fix first, re-run to green, then push. Docs-only pushes exempt
from the test gate; still format changed `.md`.

## Destructive ops & data safety

- Any destructive/`--apply` job gets one **live dry-run against real data**
  before first production use — mocked tests cannot catch driver-shape
  mismatches (one silent no-op survived 5 spec-review rounds + 3 code reviews
  because every reviewer reasoned over the mock).
- Never add row/size caps that fail a job or drop data when volume exceeds a
  threshold — packet/OOM limits are a **batching** problem (chunk the writes so
  every row persists); volume anomalies are caught by observability, not by
  failing the job.

## Cross-repo MySQL scars

- Unaliased `information_schema` columns come back **UPPERCASE** from the
  driver; a lowercase-keyed mock passes green while prod resolves `undefined`.
  Alias in SQL (`AS table_name`) + read defensively
  (`row.table_name ?? row.TABLE_NAME`). Hit twice, two repos.
- Resolving strings to ids via a pre-fetched name→id map against a `*_ci` /
  `*_ai_ci` UNIQUE column: normalize BOTH sides first, or resolve per-row with
  `WHERE name = ?` (rides the column collation). An exact-match map keyed on raw
  input silently misses every casing/accent variant — one repo dropped 48.8% of
  its edges this way.
