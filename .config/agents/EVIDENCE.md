# Evidence & Claim Rules

Rules for authoring specs, plans, reviews, and any decision-gating claim.
Distilled from real authoring failures — primary source
`crawly-mccrawlface/docs/incidents/2026-07-09-spec-authoring-errors-5w1h.md`;
other scars cited inline where they differ. Each rule targets a reasoning
mechanism, not "be careful."

## 1. Scope every negative finding

Never write a bare negative ("no references", "table empty", "unused"). Write
the searched set into the finding: "no references **in crawly**", "empty **on
rds.02**". A reader (including future you) silently upgrades an unscoped
negative to a universal one. Reader side: an inherited negative without stated
scope is unverified — rule 9 applies.

## 2. Blast radius before removing or disabling anything

Sweep depth scales with undo-cost. Hard-irreversible (DROP/DELETE of data,
destroying a resource, revoking access you can't re-grant identically) gets the
full sweep below. Consequential-but-reversible (disabling a cron or feature
flag, retiring an endpoint — the change undoes via toggle or revert+redeploy,
the effect window doesn't) gets a sweep scoped to known/likely consumers during
that window. For the full sweep, enumerate **every place a client could live**,
not just the current repo:

- all repos in the workspace (grep each, record repo + verdict per repo)
- non-repo clients: cron on hosts, systemd timers, k8s CronJobs, dashboards
  (Grafana/BI), scheduled queries, stored procedures, other teams' services
- dynamic references literal grep misses: string-built SQL/table names,
  config-driven names, ORM conventions

Record the sweep (what was searched, verdict each) in the spec — or, when no
spec exists, in a durable sink (commit message, handoff/incident doc, memory
file), not only in ephemeral chat. This recording rule applies to the scoped
consumer sweep too, not just the full sweep. Single-repo grep is not a blast
radius. Liveness is per-artifact: one frozen table does not imply sibling
tables/objects in the same schema are dead — verify each independently. Same
class as wrong-host checks: confirm the host/schema before declaring data absent
(against the project's topology map if it keeps one; otherwise state the
host/schema explicitly in the finding).

## 3. Dependency behaviour claims cite dependency source

Absence of a setter in application code ≠ absence of behaviour — defaults live
in the library. Any claim about a dependency's runtime behaviour (pool timeouts,
retries, buffer limits, server variables) cites the dependency's source or docs
at the **pinned version** (path + line; sources are on disk:
`~/.cargo/registry`, `node_modules`, composer `vendor/`, Python
site-packages/venv, vendored code) — or is marked `UNVERIFIED` in the doc. Same
for server/kernel defaults (`group_concat_max_len`, `LimitNOFILE`, sql_mode):
name the default and where it is set.

## 4. Absolute words are citation triggers

In factual/empirical claims about code, data, or system behaviour — not in
normative policy text such as this file — "forever", "never", "always", "all",
"none", "impossible", "guaranteed" each demand a citation on the same line — or
get replaced with the precise bounded statement the evidence supports ("forever"
→ "until the 10-min idle reap"). Precision, not hedge words: adding "probably"
satisfies nothing. This holds under terse/caveman output modes: a bounded
factual claim is technical substance, not fluff to drop. Confident fluent prose
is precisely what reviewers skip; confidence must track evidence, not fluency.
The dangerous errors are the confident ones.

## 5. Compute acceptance numbers from the change's own logic

A number that will gate or validate a change must be computed by the query/logic
the change will actually use, run against current data — never read off a
pre-existing materialized artifact whose contents already encode the bug being
fixed. If the change alters a table, that table is not evidence about the
change. Corollaries: baselines taken from buggy runs are contaminated;
`TABLE_ROWS` is an InnoDB estimate — use `COUNT(*)` (or an exact `GROUP BY`) for
anything that gates acceptance; any new cost model/estimate is validated against
the provider's billing export (compare PER-ROW cost, not totals) before its
numbers are quoted or used for decisions — two uncalibrated assumptions once
compounded to a 3× understatement ("$219" quoted, $664 billed; UK-278 scar,
crawly `AGENTS.md` §Gotchas).

## 6. Quote current behaviour before claiming a delta

"This change makes X worse/better/slower/wider" requires reading the current
implementation and citing statement order (`file:line`), not recalling its
shape. Shape-recall inverts conclusions (TRUNCATE-then-INSERT vs
INSERT-then-swap). Includes transaction semantics: DDL/TRUNCATE self-commit —
"previous content intact" claims must check what already committed. Applies to
**conversation, not just specs**: a claim that steers an owner's decision in
chat is held to the same standard as spec text — chat gets zero review rounds,
so it needs the citation more.

## 7. Fixes are claims

A correction folded in during review needs the same verification as the original
claim — round N's fix can carry round N's new falsehood (right conclusion, wrong
mechanism still poisons the doc). After every fold, re-read the edited region as
a **reader**, checking it against facts established elsewhere in the same
document. If a fact is stated in several places, update all or link to one.

## 8. No unsafe options in specs

A spec is executed without the author's context; an instruction admitting a
plausible wrong reading will be read wrongly. Don't offer an implementation
choice at all unless the owner must decide it — options the author can resolve,
the author resolves. If one option is unsafe, don't list it as an option — name
it and forbid it with its failure mode. Listing options ranks them implicitly;
the safe path must be the only path or the explicit recommendation. Write
implicit constraints explicitly: session-scoped state (`SET SESSION …`),
ordering invariants, required env — the "obvious" placement is the one the
implementer will get wrong.

## 9. Inherited claims re-verify before they gate action

Handoff docs, memory files, prior-session summaries, and reviewer findings are
**claims, not facts**. Before one gates a consequential action (either rule-2
tier, or any step that's costly to walk back), re-verify it and note provenance
("per handoff X, re-verified against Y"). The costliest near-miss was an
inherited single-repo negative treated as a universal fact.
