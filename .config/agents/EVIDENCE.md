# Evidence & Claim Rules

Rules for authoring specs, plans, reviews, and any decision-gating claim.
Distilled from real authoring failures
(`crawly-mccrawlface/docs/incidents/2026-07-09-spec-authoring-errors-5w1h.md`).
Each rule targets a reasoning mechanism, not "be careful."

## 1. Scope every negative finding

Never write a bare negative ("no references", "table empty", "unused"). Write
the searched set into the finding: "no references **in crawly**", "empty **on
rds.02**". A reader (including future you) silently upgrades an unscoped
negative to a universal one. Symmetric reader rule: an inherited negative
without stated scope is unverified — re-establish it before acting.

## 2. Blast radius before anything irreversible

DROP / delete / disable / retire requires enumerating **every place a client
could live**, not the current repo:

- all repos in the workspace (grep each, record repo + verdict per repo)
- non-repo clients: cron on hosts, systemd timers, k8s CronJobs, dashboards
  (Grafana/BI), scheduled queries, stored procedures, other teams' services
- dynamic references literal grep misses: string-built SQL/table names,
  config-driven names, ORM conventions

Record the sweep (what searched, verdict each) in the spec. Single-repo grep is
not a blast radius. Same class as wrong-host checks: verify the host/schema
against the topology map before declaring data absent.

## 3. Dependency behaviour claims cite dependency source

Absence of a setter in application code ≠ absence of behaviour — defaults live
in the library. Any claim about a dependency's runtime behaviour (pool timeouts,
retries, buffer limits, server variables) cites the dependency's source or docs
at the **pinned version** (path + line; sources are on disk:
`~/.cargo/registry`, `node_modules`, vendored crates) — or is marked
`UNVERIFIED` in the doc. Same for server/kernel defaults
(`group_concat_max_len`, `LimitNOFILE`, sql_mode): name the default and where
it's set.

## 4. Absolute words are citation triggers

"forever", "never", "always", "all", "none", "impossible", "guaranteed" — each
demands a citation on the same line, or gets softened. Confident fluent prose is
precisely what reviewers skip; confidence must track evidence, not fluency. The
dangerous errors are the confident ones.

## 5. Measure the post-change side

A number used as an acceptance threshold must be computed from the **post-change
source of truth** (e.g. re-run the aggregate query), never read off the
pre-change artifact. If the change alters a table, that table is not evidence
about the change. Corollaries: baselines taken from buggy runs are contaminated;
`TABLE_ROWS` is an InnoDB estimate — use `COUNT(*)` (or exact `GROUP BY`) for
anything that gates acceptance.

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
plausible wrong reading will be read wrongly. If one option is unsafe, don't
list it as an option — name it and forbid it with its failure mode. Listing
options ranks them implicitly; the safe path must be the only path or the
explicit recommendation. Write implicit constraints explicitly: session-scoped
state (`SET SESSION …`), ordering invariants, required env — the "obvious"
placement is the one the implementer will get wrong.

## 9. Inherited claims re-verify before they gate action

Handoff docs, memory files, prior-session summaries, and reviewer findings are
**claims, not facts**. Before one gates an irreversible action, re-verify it and
note provenance ("per handoff X, re-verified against Y"). The costliest
near-miss was an inherited single-repo negative treated as a universal fact.
