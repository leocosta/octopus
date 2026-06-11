---
name: definition-of-done
model: sonnet
description: >
  Create, update, and validate the team's Definition of Done (docs/definition-
  of-done.md). create/update scaffolds from a template and grills the manager
  for team items; validate walks a diff/PR against the checklist
  (met/unmet/not-applicable). Signal-only contract referencing existing
  enforcement (architect, security, audit-*, guardrails) — never gates a
  commit. Consumed by codereview.
triggers:
  keywords: ["definition of done", "is this done", "done criteria", "ready to merge", "ready to ship", "our DoD", "definition-of-done"]
---

# Definition of Done

## Overview

"Done" is usually implicit — fragments scattered across the PRD, triage,
and the reviewer's head — so the bar for *ready to merge / ready to ship*
gets applied inconsistently. This skill makes it a **first-class,
versioned artifact**: `docs/definition-of-done.md`, authored from a
template, stating the team's done criteria explicitly so every engineer's
agent checks against the same contract.

The DoD is a **contract, not an implementation**. Each item names the
role, skill, or rule that *enforces* it ("security-sensitive diffs pass
`security`", "irreversible decisions have an ADR"). It does not reimplement
any audit, and it never blocks a commit. It is **signal-only**: it reports
which items are met and which are not, and leaves the call to a human.

This skill has two modes — **create/update** (author the artifact) and
**validate** (check a change against it).

## When to Engage

- Someone asks "is this done?", "are we ready to merge/ship this?", or
  "what's our definition of done?" → **validate** (if the DoD exists) or
  **create** (if it doesn't).
- The manager wants to establish or revise the team's done criteria →
  **create/update**.
- The `codereview` flow reaches its DoD step → **validate** (see
  Integration).

Do **not** engage to:
- Gate or block a commit/merge — this skill signals; hooks and roles gate.
- Re-run an audit's logic — point at the audit, don't restate it.
- Capture **per-feature** acceptance criteria — that stays in `doc-prd`.
  The DoD is the team-wide baseline under every feature.

## Mode: create / update

Authors or revises `docs/definition-of-done.md`.

1. **Check for an existing DoD.** If `docs/definition-of-done.md` exists,
   load it and switch to revising it rather than overwriting.
2. **Scaffold from the template** `templates/definition-of-done.md` — the
   checklist grouped by concern (Tested, Reviewed, Documented, Grounded,
   Clean, Released safely), each item a checkable statement with an
   enforcement pointer.
3. **Grill the manager** to fill the gaps — one question at a time, the way
   `doc-design` fills a spec. Tailor the baseline to what this team
   actually enforces and add the **team-specific items** the baseline
   doesn't cover (feature-flag hygiene, analytics events, accessibility,
   observability, runbook updates…). Keep every item in the
   **statement → enforcer** shape.
4. **Write** `docs/definition-of-done.md`, stamp the owner and date, and
   stop. The artifact is the deliverable; it's reviewed and committed like
   any doc.

For very large teams the DoD can be split per-area via a module-scoped
sub-context (`doc-subcontext`) — the same shape, narrowed to one module.

## Mode: validate

Walks a diff or PR against the DoD checklist and reports a verdict per item.

1. **Locate the DoD.** If `docs/definition-of-done.md` is **absent**, this
   mode is a **no-op**: say there's no DoD to check against and suggest
   running create mode. Do not invent criteria.
2. **Read the diff** (`git diff --name-only HEAD` for uncommitted work, or
   the PR diff) to know which concerns the change touches.
3. **Walk each checklist item** and assign one verdict:
   - **met** — the item is satisfied by the change (evidence: a test added,
     an ADR present, formatter clean…).
   - **unmet** — the item applies but isn't satisfied. Attach a **pointer**
     to the role/skill that closes the gap (e.g. missing tests →
     `test-tdd` / `rules/common/testing.md`; no ADR for an irreversible
     change → `doc-adr`; ungrounded enum → `audit-grounding`).
   - **not-applicable** — the change doesn't touch this concern (e.g. no
     money code, so `audit-money` items are n/a).
4. **Report**, grouped by verdict. This is **signal**: an `unmet` item is a
   prompt to act, not a block. Hard blocking stays with the guardrails
   hooks and the review roles.

### Output shape

```
Definition of Done — validation
================================
Source: docs/definition-of-done.md
Diff: <N> files changed

UNMET (n)
  [Tested]     No test for the new enrollment filter. → test-tdd / rules/common/testing.md
  [Documented] Public DTO changed without a contract update. → audit-contracts

MET (n)
  [Clean]      Formatter + type check pass.
  [Grounded]   Enum names match CONTEXT.md.

NOT-APPLICABLE (n)
  [Released safely] No money/tenant/contract code touched.
```

## Anti-Patterns

- **Reimplementing an audit.** The DoD says "security audit passes" and
  points at `security` / `audit-security`; it never restates their checks.
- **Gating.** This skill never blocks a commit or merge. It signals; the
  guardrails hooks and review roles are the gate.
- **Inventing criteria** when no DoD exists — validate is a no-op that
  suggests creating one, not a fallback checklist.
- **Duplicating per-feature acceptance criteria** — those live in
  `doc-prd`. The DoD is the team-wide baseline.
- **Letting it rot into a shelf document** — it earns its keep by being
  exercised in every `codereview`, not by being written once.

## Integration with Other Skills

- **`codereview`** — the self-review orchestrator runs validate as a step
  so the consolidated report answers "done per our DoD?" alongside the
  audit findings. Additive and no-op when the DoD is absent.
- **`doc-design`** — the grilling pattern create mode borrows to fill
  team-specific items.
- **`doc-subcontext`** — how a per-area DoD is scoped to one module.
- **`doc-adr`** — the enforcer the "Documented" items point at for
  irreversible decisions.
- **`audit-grounding`** / **`standards`** — the enforcers behind the
  "Grounded" items (drift detection and standard lookup over the same
  sources).
- **`audit-money` / `audit-tenant` / `audit-contracts`** — the `audit-*`
  family the "Released safely" items reference when those concerns are
  touched.
- **roles `architect` / `security` / `dba`** — the human-judgment enforcers
  the "Reviewed" items point at; the DoD is the contract, the role is one
  enforcer of it.
- **`guardrails` hooks** — the deterministic, blocking floor (formatter,
  type check, secret scan, `--no-verify` block) the "Clean" items point at.
