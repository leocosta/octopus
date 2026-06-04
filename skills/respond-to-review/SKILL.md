---
name: respond-to-review
description: >
  The Octopus PR-feedback discipline — verify the critique, ask for evidence
  on generic comments, separate reasoned feedback from preference, never make
  performative changes, clarify ambiguity. Runs the post-fix loop (commit,
  conditional push, inline replies, resolve threads) end-to-end in one turn.
  Active by default on every PR feedback loop.
---

# Respond-to-Review Protocol

## Overview

The discipline side of processing review feedback: what an agent does
with each comment before acting. `/octopus:pr-comments` owns the
mechanics (walking the thread). With `implement` (new code) and `debug`
(broken code), this completes the `starter` workflow trio — one skill
per working state.

Stack-neutral: a five-rule protocol, not a tool or platform. Never
duplicates `rules/common/*`. When `superpowers:receiving-code-review`
is installed it wins per rule on what it covers; this skill still owns
the `pr-comments` integration and the hand-offs to `implement`/`debug`.

## When to Engage

Engage whenever the task is **processing PR feedback** — a reviewer
comment, `/octopus:pr-comments <n>` running, the user quoting a
reviewer, an open thread awaiting response. Do **not** engage for:
writing a review on someone else's PR (`/octopus:pr-review`); feature
work or bug triage not originating from a review comment (`implement` /
`debug`); docs-only changes with no review attached.

Engagement is implicit (Claude Code matches the description); invoke
`/octopus:respond-to-review <ref>` for an explicit single-comment walk.

## The Five Rules

Five rules applied to every comment before any code change. Skip a
rule only with a stated reason.

### Rule 1. Verify the critique against the code

Read the code the reviewer pointed at before accepting the feedback —
does the code actually behave as claimed? If the reviewer is wrong, say
so with evidence (quote the lines that contradict it); a wrong reviewer
wants to know. If right, acknowledge and proceed through the rest.

### Rule 2. Ask for evidence on generic comments

Generic critiques ("ugly", "seems wrong", "could be better") describe
no concrete concern — ask for specificity ("which part — name,
structure, nesting?"). Never infer what a generic comment means and
edit on that inference; the reviewer has context you don't.

### Rule 3. Separate reasoned feedback from preference

Reasoned critiques carry a technical reason (performance,
maintainability, correctness, security); restate the reason so the
reviewer sees you got it, then apply, push back with a counter-reason,
or propose an alternative. Preference is a negotiation, not an
instruction — "I'd keep X because Y, but happy to switch if you feel
strongly." Don't treat preference as authority.

### Rule 4. Never make performative changes

A performative change closes a thread without understanding why — the
real concern stays unaddressed, the code gets worse, and the pattern
repeats. If you don't understand, use Rule 2 or 5; if you understand
and disagree, use Rule 3. Never edit code just to close a thread.

### Rule 5. Ask for clarification on ambiguity

When a critique allows more than one reading ("this could be a helper"
— which scope?; "handle the error case" — which case, doing what?;
"rename this" — to what?), ask before acting. One clarifying question
beats a second feedback round on a wrong guess.

## Post-Fix Loop

The rules end when the *right* change is applied; the skill does not.
After the last fix, open a single **post-fix turn** proposing four
closing actions in one consolidated menu:

1. **Commit** — one batch commit for all review-driven edits, with a
   proposed message (`fix(<scope>): address review feedback on #<pr>`).
   Approve / edit / skip.
2. **Push** — automatic when an upstream tracking ref exists
   (`git rev-parse --abbrev-ref --symbolic-full-name @{u}` succeeds);
   otherwise surface `git push -u origin HEAD` as an explicit
   confirmation. Never push `-u` silently.
3. **Reply inline per thread** — canned `Addressed in <sha>.` for
   direct fixes; contextual for push-back/partial (e.g.
   `Kept current behavior because <reason>. — <sha>.`), composed from
   the Rule 3 verdict already produced.
4. **Mark threads resolved** — resolve threads with a fix applied or a
   reasoned counter-argument; **leave open** threads pending a Rule 5
   clarification. Uses the GraphQL `resolveReviewThread` mutation;
   thread IDs are collected at the start alongside the comment payload.

### Menu shape

A single block, defaults pre-filled, approve-edit-skip in one
round-trip — one line per action plus the commit message and
classification counts (e.g. `Resolve: 3 fix + 1 push-back, 1
clarification stays open`). The user approves in a word, edits any line
in place, or skips items (the skill then reports what was left).

### Failure handling

If the commit succeeds but a later step fails (push rejected, GraphQL
error), report the partial state (which threads got replies / resolved)
explicitly. Do **not** roll back the commit or silently retry — the
user decides whether to re-run the failed step.

## Task Routing

<!-- BEGIN task-routing -->
When a task starts, scan the signals below and consult the
matching companion skills alongside the core workflow. Signals
are heuristics — more than one may apply; treat them as a
checklist, not a switch statement.

**Stack / language signals**

| Signal | Consult |
|---|---|
| Paths under `api/**/*.cs`, `*.sln`, `*.csproj`; stack traces with `System.*` | `dotnet`, `backend-developer` role |
| Paths under `app/**/*.tsx`, `*.jsx`, `*.vue`; UI-layer bugs; reviewer comments about rendering / accessibility | `frontend-developer` role |
| Node/TypeScript backend (`apps/api/**/*.ts`, `package.json` with `express`/`fastify`/`hono`/`nestjs`) | `backend-patterns`, `backend-developer` role |
| Astro / Next.js landing page (`lp/`, `apps/lp/`, `src/pages/`) | `frontend-developer` role |

**Domain-audit signals**

| Signal | Consult |
|---|---|
| Keywords `payment`, `billing`, `split`, `fee`, `invoice`, `subscription`; paths `billing/`, `payment/` | `audit-money` |
| New `DbSet<X>`, multi-tenant queries, `[Authorize]` changes, `IgnoreQueryFilters()` | `audit-tenant` |
| Change touches both `api/` and `app/` (or `lp/`) in the same diff; DTO/endpoint changes | `audit-contracts` |
| Secrets, env vars, `detect-secrets` warnings, authentication paths | `audit-security` |
| Pre-merge on a non-trivial PR that touches billing or multi-tenant data | `audit-all` (composer — runs all four audits in parallel) |

**Cross-workflow signals**

| Signal | Consult |
|---|---|
| Trigger is a **new feature** or **refactor** (not a reported bug or review comment) | Stay in `implement` |
| Trigger is a **bug report**, **failing test**, **stack trace**, or **regression** | Hand off to `debug` (Phase 3 uses `implement`'s TDD loop for the fix) |
| Trigger is a **PR review comment** | Hand off to `respond-to-review` (Rule 1 verifies, then handoff back to `implement` or `debug` per the comment's intent) |
| Task involves both docs and code | Compose with `doc-lifecycle` for docs (RFC / Spec / ADR), use the appropriate workflow skill for the code |

**Risk-profile signals**

| Signal | Consult |
|---|---|
| Large-scale / cross-module change (touches ≥ 3 modules) | Escalate `implement`'s plan-before-code gate to a spec via `/octopus:doc-spec`; add an ADR via `/octopus:doc-adr` if the change encodes a decision |
| Data migration, schema change, irreversible operation | Keep `debug`'s Phase 3 regression test; consider an ADR; consider tagging the change for the destructive-action guard hook |
| Release-triggering change | Pair with `launch-release` (retention) or `launch-feature` (acquisition) for the user-facing announcement after merge |

**Graceful degradation**

A companion skill that isn't installed in the current repo
doesn't block the workflow — the main skill continues with
`rules/common/*` and whatever else is available. Surface the
gap once, as a hint: "this task would benefit from
`<skill-name>`; add it to `.octopus.yml` to enable."

Don't stall. Don't block. Don't invent advice the missing skill
would have provided — point at the gap and move on.
<!-- END task-routing -->

## Integration with Other Skills

- **`/octopus:pr-comments`** — alternative entry point that walks a
  PR's threads from scratch. This skill is end-to-end on its own (five
  rules + post-fix loop); use `pr-comments` for the older
  one-thread-at-a-time mechanics.
- **`/octopus:pr-review`** — writes a review for someone else's PR;
  different flow, this skill never engages there.
- **`implement`** — when a comment asks for a code change, `implement`
  drives the edit; this skill ensures it's the *right* change first.
- **`debug`** — when a comment flags a bug, hand off to `debug`
  (reproduce → isolate → fix with regression test); Rule 1 (verify)
  runs before the handoff.
- **`rules/common/*`** — always-on static rules; reference only, never
  restated.
- **`superpowers:receiving-code-review`** — when installed it wins per
  rule on what it covers; this skill keeps the `pr-comments`
  integration and the `implement`/`debug` handoffs.

## Anti-Patterns

This skill forbids, by name:

- Accepting a critique without reading the code it points at.
- Performative compliance — changing code to close a thread without
  understanding the concern.
- Treating reviewer preference as a technical requirement.
- Acting on your inference of a generic comment instead of asking.
- Skipping the ambiguity clarification, then finding the change didn't
  match the reviewer's actual ask.
- Pushing back on every comment without reading the code (the opposite
  failure from blind deference).
- Deleting a reviewer's thread without resolving or acknowledging it.
- **Batching** unrelated cleanup into the post-fix commit — it covers
  *only* the changes that answer review comments; other work gets its
  own commit.
- Ending after the last fix without running the post-fix loop (the
  manual commit/reply/resolve regression this skill prevents).
- Pushing `-u` to a new remote branch silently instead of via explicit
  confirmation.
- Auto-resolving a thread that ended in a Rule 5 clarification request.
