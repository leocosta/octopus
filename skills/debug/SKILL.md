---
name: debug
description: >
  The Octopus bug-fix workflow — reproduce deterministically,
  isolate, fix with a regression test first, document non-obvious
  cause. Active by default on every bug-triage task; pairs with
  implement (features) and composes with audit-all (pre-merge
  review after the fix).
---

# Debugging Protocol

## Overview

This skill codifies the bug-fix side of coding inside Octopus.
`implement` covers features ("how to write new code"); this skill
covers bugs ("how to find why something broke"). The two are a
pair — both live in the `starter` bundle and engage
automatically, `implement` on code-authoring tasks and
`debugging` on bug-triage ones.

The skill is stack-neutral. It describes a four-phase protocol,
not specific debuggers or languages. It never duplicates
`rules/common/*`. When the `superpowers:*` plugin is installed,
its `systematic-debugging` skill wins per phase on the practices
it already covers; this skill still owns Phase 4 (Octopus-native
integration with `continuous-learning` and ADRs).

## When to Engage

Engage whenever the task starts from a **failure** in the current
working copy — bug report, failing test, stack trace, regression,
unexpected behavior a user flagged. Do not engage for:

- Feature work (that's `implement`)
- Read-only analysis of a stack trace seen elsewhere (e.g. a blog
  post or external log) — no repository fix is implied
- Documentation-only changes
- Brainstorming / research

Engagement is implicit — Claude Code discovers this skill from
`.claude/skills/` and applies it automatically when the description
matches the task. Users who want explicit control can invoke
`/octopus:debugging <bug>` for a single-task walk.

## The Four Phases

The protocol is four phases applied in order on every bug. Skip a
phase only with a stated reason; always prefer the full loop when
the bug is reproducible.

### Phase 1. Reproduce deterministically

Before proposing a cause, establish a command or sequence that
reproduces the bug 100% of the time. If the bug is intermittent,
stop and gather more context (logs, environment, input data, user
agent, timing) until it becomes deterministic.

"Works on my machine" and "sometimes happens" are not starting
points — they are symptoms of missing context. Examples of
deterministic handles:

- A command-line invocation that triggers the failure every run.
- A test case (even one marked `.skip` or `.only`) that fails
  when run.
- A script that exercises the HTTP endpoint + payload that
  produces the error.

If, after a reasonable effort, the bug cannot be made
deterministic, surface the gap to the user and describe what
additional context (env vars, data, timing) would be needed.

### Phase 2. Isolate

With a deterministic reproduction, narrow down the responsible
change. Tools and techniques (skill is stack-neutral — use
whatever applies):

- `git bisect` when the bug is a regression (worked at commit A,
  fails at commit B).
- Hypothesis → test → refute. Write the hypothesis down; find
  the smallest experiment that would falsify it; run it.
- Narrow by axis: which input, which environment variable, which
  code path, which dependency version.
- Logs confirm hypotheses; they do not substitute for isolation.
  Reading logs to "figure out what happened" without a hypothesis
  is guessing.

Stop isolating when the root cause is identified — not when a
superficial symptom is patched.

### Phase 3. Fix with a regression test first

Write the failing test before writing the fix. The test:

- Fails against the current (buggy) code with the same error the
  user reported.
- Passes once the fix is in place.
- Lives in the project's normal test suite so future regressions
  are caught.

This is the same red → green → commit loop as `implement`'s TDD
practice, but the red step comes from the bug instead of a new
feature. Once the regression test is green, the simplify pass
from `implement` still applies — review the change for
duplication, dead code, unclear names before committing.

### Phase 4. Document non-obvious cause

If the root cause is not obvious from the diff, write it down so
future readers — including future agents — can learn from it.
Decide based on the scope:

- **Bug-specific cause** (a subtle interaction, a race condition,
  a misunderstood API) → explain in the commit message body.
- **Pattern likely to recur** (an entire class of bugs, a
  project-wide gap) → add to `knowledge/<domain>/` via
  `continuous-learning`, or open an ADR if it changes an
  architectural choice.
- **Environment or process issue** (a CI misconfig, a dev-env
  quirk) → open an issue / RM and link from the commit.

Silent fixes ("it works now") that skip this phase are how the
same bug recurs six months later under a different symptom.

## Task Routing

<!-- BEGIN task-routing -->
When a task starts, scan the signals below and consult the
matching companion skills alongside the core workflow. Signals
are heuristics — more than one may apply; treat them as a
checklist, not a switch statement.

**Stack / language signals**

| Signal | Consult |
|---|---|
| Paths under `api/**/*.cs`, `*.sln`, `*.csproj`; stack traces with `System.*` | `dotnet`, `backend-specialist` role |
| Paths under `app/**/*.tsx`, `*.jsx`, `*.vue`; UI-layer bugs; reviewer comments about rendering / accessibility | `frontend-specialist` role |
| Node/TypeScript backend (`apps/api/**/*.ts`, `package.json` with `express`/`fastify`/`hono`/`nestjs`) | `backend-patterns`, `backend-specialist` role |
| Astro / Next.js landing page (`lp/`, `apps/lp/`, `src/pages/`) | `frontend-specialist` role |

**Domain-audit signals**

| Signal | Consult |
|---|---|
| Keywords `payment`, `billing`, `split`, `fee`, `invoice`, `subscription`; paths `billing/`, `payment/` | `money-review` |
| New `DbSet<X>`, multi-tenant queries, `[Authorize]` changes, `IgnoreQueryFilters()` | `tenant-scope-audit` |
| Change touches both `api/` and `app/` (or `lp/`) in the same diff; DTO/endpoint changes | `cross-stack-contract` |
| Secrets, env vars, `detect-secrets` warnings, authentication paths | `security-scan` |
| Pre-merge on a non-trivial PR that touches billing or multi-tenant data | `audit-all` (composer — runs all four audits in parallel) |

**Cross-workflow signals**

| Signal | Consult |
|---|---|
| Trigger is a **new feature** or **refactor** (not a reported bug or review comment) | Stay in `implement` |
| Trigger is a **bug report**, **failing test**, **stack trace**, or **regression** | Hand off to `debugging` (Phase 3 uses `implement`'s TDD loop for the fix) |
| Trigger is a **PR review comment** | Hand off to `receiving-code-review` (Rule 1 verifies, then handoff back to `implement` or `debugging` per the comment's intent) |
| Task involves both docs and code | Compose with `feature-lifecycle` for docs (RFC / Spec / ADR), use the appropriate workflow skill for the code |

**Risk-profile signals**

| Signal | Consult |
|---|---|
| Large-scale / cross-module change (touches ≥ 3 modules) | Escalate `implement`'s plan-before-code gate to a spec via `/octopus:doc-spec`; add an ADR via `/octopus:doc-adr` if the change encodes a decision |
| Data migration, schema change, irreversible operation | Keep `debugging`'s Phase 3 regression test; consider an ADR; consider tagging the change for the destructive-action guard hook |
| Release-triggering change | Pair with `release-announce` (retention) or `feature-to-market` (acquisition) for the user-facing announcement after merge |

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

- **`implement`** — features workflow. `debugging` handles bug
  triage up through the fix; the TDD loop inside `implement` is
  reused in Phase 3. They are paired members of the `starter`
  bundle.
- **`audit-all`** — pre-merge audit. Run after a bug fix before
  opening the PR, especially when the fix touches billing, tenant
  scope, or cross-stack contracts.
- **`continuous-learning`** — when a Phase 4 finding is a
  recurring pattern, capture it there so future agents avoid the
  same class of bug.
- **`rules/common/*`** — always-on static rules. `debugging`
  never re-states rule content; reference only.
- **`feature-lifecycle`** — if the bug has architectural
  implications, escalate to an ADR via `/octopus:doc-adr`.
- **`superpowers:systematic-debugging`** — when the superpowers
  plugin is installed, that skill wins per phase on the
  practices it covers. `debugging` still owns Phase 4 (Octopus-
  native integration with `continuous-learning` / ADR).

## Anti-Patterns

This skill forbids, by name:

- Proposing a fix without reproducing the bug first (for
  reproducible failures).
- Committing a fix without a regression test.
- Reading code to guess the cause instead of forming a hypothesis
  and testing it.
- Swallowing errors (empty `try`/`catch`, `|| true`, generic
  `ignore` handlers) to make the failure go away.
- Silent retry with backoff as a first response to a transient
  failure — investigate before retrying.
- Hiding the bug behind a feature flag or env toggle without
  investigating the root cause.
- "Works on my machine" / "sometimes happens" declarations
  accepted without a reproduction path.
- Macro-commits that fold bisect artifacts, exploratory edits,
  the fix, and the regression test into one commit.
