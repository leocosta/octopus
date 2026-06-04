---
name: codereview
description: (Octopus) Self-review of uncommitted changes — orchestrates audit skills and review roles based on what the diff touches, then runs a minimal fallback checklist.
---

# /octopus:codereview

Self-review of **uncommitted** changes. Acts as a router: detects
what the diff touches, dispatches the relevant audit skills and
review roles in parallel, then runs a minimal fallback checklist
for things no skill covers. Aggregates into one severity-tiered
report.

For **receiving** PR feedback, use `/octopus:respond-to-review`.
For **reviewing** an open PR (self-review + assign reviewers),
use `/octopus:pr-review`.

## Phase 0 — Size Gate (single-pass vs fan-out)

Measure the diff: `git diff --stat HEAD`. For a **small** diff —
under ~150 changed lines and touching no data/auth/money/tenant
path (Phase 1 matrix) — **do not fan out**. Run one consolidated
review pass over the whole diff (the Phase 3 checklist plus a quick
correctness/design read) and go straight to Phase 4. Fan-out's
per-agent diff re-read is wasted on small, low-risk changes.

Otherwise continue to Phase 1.

## Phase 1 — Detect Change Type

1. `git diff --name-only HEAD` to list changed files.
2. Classify each path against the matrix below, and **record which
   files matched each row** — that file subset is what the dispatched
   skill/role receives in Phase 2, not the whole diff.

| Signal in the diff | Dispatch |
|---|---|
| `migrations/**`, `db/**`, `**/*.sql`, Mongo schemas, Redis configs, ORM mappings | role `dba` |
| Auth, JWT, OAuth, secret/token handling, `.env*`, password/credential paths | role `security` |
| `billing/`, `payment/`, money-touching code (`Decimal`, `cents`, fee/invoice/subscription) | skill `audit-money` |
| New `DbSet<X>`, multi-tenant queries, `IgnoreQueryFilters()`, `tenant`/`org`/`workspace` predicates | skill `audit-tenant` |
| Both `api/` and `app/`/`lp/` in same diff; DTO/endpoint/enum changes | skill `audit-contracts` |

Dispatch **only** the rows that matched — the same deterministic map
the `pre-push-audit-suggest` hook uses (`cli/lib/audit-map.sh`); a
row with no matching files is not dispatched.

**`architect`** is dispatched when the change is non-trivial: it
touches a data/auth/money/tenant/contract path above, OR the diff
exceeds ~150 lines, OR it changes public API/architecture. A small,
self-contained change that matched no matrix row was already handled
by Phase 0 and needs no architect pass.

If the diff touches the data layer, **both** `dba` and `architect`
must approve (dual gate — see `.claude/core/pr-workflow.md`). Likewise, if the
diff touches auth/secrets, **both** `security` and `architect` must
approve. The `security` role runs the `audit-security` checklist as its
baseline and adds threat modeling over the diff.

## Phase 2 — Dispatch in Parallel

Invoke the matched skills and roles **concurrently** — they do not
depend on each other. Pass each one **only its domain-matching file
subset** from Phase 1 (e.g. `audit-tenant` sees the tenant-scoped
files, not the frontend diff) — this is the dominant token cost, so
scoping it down is the point.

Dispatch the **`audit-*` skills on the cheapest model tier** (they are
mechanical checklist passes — see each skill's *Model tier* note); run
the **roles (`architect`, `dba`, `security`) on their declared model**
(Opus — they adjudicate, see `roles/*.md`) (RM-130). Roles emit findings
in the format defined by their own role files; skills emit per their
`audit-*` Output Format.

## Phase 3 — Fallback Checklist

After the dispatched skills/roles return, run this minimal
checklist on the diff. It covers only what no skill above
covers:

- `TODO` / `FIXME` / `HACK` / `XXX` comments introduced in this
  diff (any new occurrence is a finding)
- `console.log`, `print()`, `dump()`, `dd()`, `debugger`,
  `binding.pry`, or equivalent left in non-test files
- Emoji in source files (when project convention forbids them —
  check `rules/common/coding-style.md`)
- Files exceeding 800 lines (after the change)
- Functions exceeding 50 lines (after the change)
- Nesting depth > 4 levels introduced or worsened in this diff

These are *static heuristics*, not deep analysis. Anything more
substantive should be in a skill or role above; if it isn't,
that's a gap to fix in the skill catalogue, not by inflating
this checklist.

## Phase 3.5 — Definition of Done

If `docs/definition-of-done.md` exists, run the `definition-of-done`
skill in **validate** mode against the same diff and fold its
per-item verdict (met / unmet / not-applicable) into the report so
the self-review answers "done per our DoD?" alongside the audits.

This step is **additive and signal-only**: a DoD `unmet` item is an
ADVISORY finding (`origin: definition-of-done`), never a BLOCKING
one — hard blocking stays with the roles and guardrails hooks. When
the DoD is **absent**, this step is a **no-op**: skip it silently
(optionally suggest creating one once, never every review).

## Phase 4 — Aggregate Report

Merge findings from all dispatched skills, roles, and the
fallback checklist into a single severity-tiered report:

```
Code Review Report
==================
Date: YYYY-MM-DD
Diff: <N> files changed

BLOCKING (n)
  [origin: dba]        ...
  [origin: architect]  ...
  [origin: security]   ...

ADVISORY (n)
  [origin: audit-contracts] ...
  [origin: fallback] TODO introduced at <path:line>

QUESTION (n)
  [origin: dba] Cannot verify table size — set MSSQL_CONNECTION_STRING
```

Severity scale follows the role/skill that produced the finding
(BLOCKING / ADVISORY / QUESTION for `dba` and `architect`;
CRITICAL / HIGH / MEDIUM / LOW for audit skills). When merging,
the report keeps each finding's native severity and groups them
under a unified order: BLOCKING ≡ CRITICAL > HIGH ≡ ADVISORY
> MEDIUM > LOW ≡ QUESTION.

## Phase 5 — Block Commit

Block the commit if any BLOCKING or CRITICAL finding is open.
Report exactly which findings must be resolved.

If only ADVISORY/MEDIUM/LOW findings remain, surface them but
allow the commit — they belong in the PR description as
follow-ups.

Never approve code with unresolved BLOCKING/CRITICAL findings.
