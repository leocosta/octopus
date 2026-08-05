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

Before dispatching an `audit-*` skill, resolve its scope
deterministically (RM-172) — this costs no model call:

```bash
octopus audit-scope <skill> --base <base> --ref <ref>
```

Branch on the marker it prints:

| Marker | Action |
|---|---|
| `skip` | **Do not dispatch.** No files matched; record it as "no changes detected" in the report. |
| `cached` | **Do not dispatch.** Fold the returned report into Phase 4 as-is. |
| `scoped` | Dispatch, passing the scoped diff that follows the marker. After the sub-agent returns, persist it: `octopus audit-scope <skill> --write <key> --from <report-file>`. |

The saving is in not spawning: a sub-agent that starts only to
discover it has nothing to review has already cost the spin-up.

Invoke the remaining skills and roles **concurrently** — they do not
depend on each other. Each dispatched audit receives **only its
domain-matching file subset** (e.g. `audit-tenant` sees the
tenant-scoped files, not the frontend diff) — this is the dominant
token cost, so scoping it down is the point. Roles (`architect`,
`dba`, `security`) have no `pre_pass` and are dispatched with the
Phase 1 file subset directly.

Dispatch each **`audit-*` skill on the tier declared in its SKILL.md
`model:` frontmatter** — spawn it as a sub-agent (Agent tool) with `model`
set to that value (`sonnet` for the domain audits, `haiku` for the
signal/config passes; never Opus — they are mechanical checklist passes).
Run the **roles (`architect`, `dba`, `security`) on their declared model**
(`roles/*.md` — Opus; they adjudicate). (RM-130) Roles emit findings in the
format defined by their own role files; skills emit per their `audit-*`
Output Format.

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

## Phase 4.5 — Anchor Verification

Before the report is printed or posted, prove every `path:line`
citation in it (RM-170). The citations are written by the model;
nothing has checked them until now.

```bash
octopus review-anchor --base <base> --ref <ref> --file <report>
```

Each finding comes back with a verdict:

| Verdict | Meaning | Action |
|---|---|---|
| `anchored` | the line exists at `<ref>` and this diff touched it | keep as-is |
| `not-in-diff` | the line exists but the change did not touch it | keep, but say so — the finding may be about pre-existing code |
| `line-out-of-range` | the file has fewer lines than cited | **demote to QUESTION**, tagged `unanchored` |
| `missing-file` | no such file at `<ref>` | **demote to QUESTION**, tagged `unanchored` |
| `no-anchor` | the line carries no citation (headers, prose) | keep as-is |

A demoted finding keeps its text and its origin — the claim may
still be true — but it can no longer block a commit on a location
nobody can verify. Report the summary line
(`OCTOPUS_ANCHOR_SUMMARY anchored=N failed=N no-anchor=N`) so a
review that produced many unanchored findings is visible as such.

This step is deterministic and costs no model call.

## Phase 4.55 — Reflection Pass

Findings are written by models and nothing has judged them yet — Phase 4.5
proved only that their locations are real. A false BLOCKING stops real work, and
the fastest way to teach a team to bypass a gate is to block them wrongly once
(RM-171).

```bash
octopus review-reflect prepare --base <base> --ref <ref> --file <report>
```

**Exit 1 means nothing was eligible — skip the rest of this phase entirely.** Do
not spawn the sub-agent. Only findings from a role or an `audit-*` skill whose
anchor resolved are adjudicable; `fallback` and `definition-of-done` findings are
deterministic and never enter.

Otherwise dispatch **one** sub-agent on the tier the payload's
`OCTOPUS_REFLECT_MODEL` line names (Agent tool, `model` set to that value). Give
it the payload and this instruction:

> For each finding, decide whether the code shown sustains the claim. The burden
> of proof is on the finding: if the window does not sustain it, `reject`. One
> exception — if the window does not show enough to judge (a claim about coupling
> across files, for instance), `keep`. Doubt favours the finding. Do not look for
> new issues and do not read files beyond what you were given. Return one line
> per finding, tab-separated: `<id>	keep|reject	<one-line reason>`.

Write its reply to a file and apply it:

```bash
octopus review-reflect apply --base <base> --ref <ref> --file <report> \
  --verdicts <verdicts-file> --filtered <filtered-file>
```

A rejected BLOCKING/CRITICAL is **demoted to ADVISORY**, not deleted — the claim
stays readable and stops gating. A rejected finding below that tier leaves the
report and lands in `<filtered-file>` for Phase 4.6. Report the
`OCTOPUS_REFLECT_SUMMARY` line so an over-aggressive filter is visible in the run
itself.

If the sub-agent fails or returns nothing usable, `apply` leaves the report
unchanged — the filter never removes what it did not explicitly reject.

## Phase 4.6 — Record the Run

Persist the aggregated report before acting on it (RM-176):

```bash
octopus review-session record --base <base> --ref <ref> \
  --report <report-file> [--audits <resolutions-file>] [--filtered <filtered-file>]
```

`--audits` takes one `<audit-name> <outcome>` per line, using the
Phase 2 `audit-scope` verdicts (`skip` / `cached` / `scoped`). Pass
it — a record that says which audits ran is the difference between
"no findings" and "nothing looked".

`--filtered` takes the file Phase 4.55 wrote. Pass it — a filter whose discards
are not recorded is a silent hole in coverage rather than a tunable one.

The record carries each finding's origin, severity, anchor verdict
from Phase 4.5, and the reviewed sha, at
`.octopus/reviews/<id>.json`. Query it later with
`octopus review-session show latest --severity BLOCKING`.

This costs no model call. It is what lets a review be consumed
later — by the team-learning capture, by CI, or by the next person
asking whether this finding has appeared before.

## Phase 5 — Block Commit

Block the commit if any BLOCKING or CRITICAL finding is open.
Report exactly which findings must be resolved.

A finding demoted by Phase 4.5 (to QUESTION, unverifiable location) or by
Phase 4.55 (to ADVISORY, claim not sustained by its own code) does **not**
block. Neither an unverifiable location nor an unsustained claim is grounds to
stop a commit.

If only ADVISORY/MEDIUM/LOW findings remain, surface them but
allow the commit — they belong in the PR description as
follow-ups.

Never approve code with unresolved BLOCKING/CRITICAL findings.
