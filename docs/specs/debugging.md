# Spec: Debugging

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-19 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **RFC** | N/A |
| **Roadmap** | RM-031 |

## Problem Statement

Bugs and test failures are a universal part of software work — every
repo encounters them regardless of stack, size, or domain. Octopus
ships a strong workflow for *features* (the `implement` skill from
RM-030: TDD, plan gate, verification, simplify, commit cadence) but
does not codify the complementary workflow for *bugs*.

Without an explicit protocol, agents (and humans) fall into known
anti-patterns when a failure shows up: reading code to guess the
cause, patching symptoms without reproducing, committing a "fix"
with no regression test, silently swallowing errors, hiding the bug
behind a feature flag, or shipping a commit whose message leaves
the next reader with no idea why the change exists.

Industry guides (Boris Cherny's Claude Code tips,
`superpowers:systematic-debugging` when installed) converge on a
short deterministic protocol: reproduce → isolate → fix with a
regression test → document non-obvious cause. RM-031 ships this
protocol as an Octopus-native skill so every repo using Octopus —
not just those that also pull in superpowers — has the workflow
available by default.

## Goals

- Ship a skill `debugging` that codifies a four-phase protocol:
  (1) reproduce deterministically, (2) isolate, (3) fix with a
  regression test first, (4) document non-obvious cause.
- Make the skill active by default in every Octopus-managed repo by
  adding it to the `starter` bundle (foundation category), pairing
  with `implement` as the features-vs-bugs complement.
- Preserve the same SKILL.md structure used by `implement`
  (Overview, When to Engage, body sections, Task Routing reserved
  hook for RM-034, Integration with Other Skills, Anti-Patterns) so
  the two skills feel like a coherent pair.
- Compose cleanly with `implement` (its TDD loop applies to the
  fix), with `audit-all` (run after a fix before merge), and with
  `superpowers:systematic-debugging` when installed (composition
  rule: more specific skill wins per phase).

## Non-Goals

- Stack- or tool-specific debugger adapters (lldb, pdb, Chrome
  DevTools, Playwright inspector). The skill is stack-neutral; it
  describes a protocol, not a tool.
- Incident postmortem templates (blameless RCA, five-whys). That's
  a separate artifact — if it lands, it's a new skill.
- Automated bug detection via hooks (e.g. a PreToolUse hook that
  scans for bug-ish keywords). The skill activates via its
  description, not via side-channel detection.
- `--fail-on` gating in CI. The skill is guidance, not a merge gate.
- Replacing `superpowers:systematic-debugging`. That skill, when
  installed, covers the same protocol with more depth; this skill
  composes with it per the `implement` precedent.
- RM-034 routing logic (the task-aware dispatcher). This spec
  reserves the section header for RM-034 to fill in.

## Design

### Overview

A pure-markdown skill at `skills/debugging/SKILL.md`, same shape as
every other Octopus skill — no new runtime, no new dependencies.
The body is organized into six sections. The skill joins
`bundles/starter.yml` next to `implement`, so every `octopus setup`
activates it automatically.

The skill is active-by-default: Claude Code discovers it in
`.claude/skills/` and engages via its description whenever a task
starts from a bug report, a failing test, a stack trace, or a
regression. Other agents receive the content concatenated into
their output file. A thin slash command `/octopus:debugging
[<bug description>]` exists for explicit invocation.

### Detailed Design

#### Invocation

```
/octopus:debugging [<bug description or failing test name>]
```

Most uses are implicit — the skill is active by default, and the
agent engages it when the task is a bug-fix flow. The slash command
is for explicit mode when auto-activation is missed or the user
wants to drive the four phases manually.

#### Skill structure

`skills/debugging/SKILL.md`:

```markdown
---
name: debugging
description: >
  The Octopus bug-fix workflow — reproduce, isolate, fix with a
  regression test, document non-obvious cause. Active by default on
  every bug-triage task; pairs with implement (features) and
  composes with audit-all (pre-merge review after the fix).
---

# Debugging Protocol

## Overview
<few sentences — complements implement; four phases; stack-neutral>

## When to Engage
<triggers: bug report / failing test / stack trace / regression;
 NOT feature-new tasks (those go to implement)>

## The Four Phases
### Phase 1. Reproduce deterministically
### Phase 2. Isolate
### Phase 3. Fix with a regression test first
### Phase 4. Document non-obvious cause

## Task Routing (reserved for RM-034)
<stub only — named extension hook>

## Integration with Other Skills
<composition — implement, audit-all, continuous-learning,
 superpowers:systematic-debugging>

## Anti-Patterns
<explicit forbidden list>
```

Section content is filled during implementation, following the
content contract below.

#### Content contract — the four phases

**Phase 1. Reproduce deterministically.**

Before proposing a cause, establish a command or sequence that
reproduces the bug 100% of the time. If the bug is intermittent,
stop and gather more context (logs, environment, input data, user
agent, timing) until it becomes deterministic.

"Works on my machine" and "sometimes happens" are not starting
points — they are symptoms of missing context. Examples of
deterministic handles:

- A command-line invocation that triggers the failure every run.
- A test case (even one marked `.skip` or `.only`) that fails when
  run.
- A script that exercises the HTTP endpoint + payload that produces
  the error.

If, after a reasonable effort, the bug cannot be made
deterministic, surface the gap to the user and describe what
additional context (env vars, data, timing) would be needed.

**Phase 2. Isolate.**

With a deterministic reproduction, narrow down the responsible
change. Tools and techniques (skill is stack-neutral, so use
whatever applies):

- `git bisect` when the bug is a regression (worked at commit A,
  fails at commit B).
- Hypothesis → test → refute. Write down the hypothesis; find the
  smallest experiment that would falsify it; run it.
- Narrow by axis: which input, which environment variable, which
  code path, which dependency version.
- Logs confirm hypotheses; they do not substitute for isolation.
  Reading logs to "figure out what happened" without a hypothesis
  is guessing.

Stop isolating when the root cause is identified — not when a
superficial symptom is patched.

**Phase 3. Fix with a regression test first.**

Write the failing test before writing the fix. The test:

- Fails against the current (buggy) code with the same error the
  user reported.
- Passes once the fix is in place.
- Lives in the project's normal test suite so future regressions
  are caught.

This is the same red → green → commit loop as `implement`'s TDD
practice, but the red step comes from the bug instead of a new
feature. Once the regression test is green, the simplify pass from
`implement` still applies — review the change for duplication,
dead code, unclear names before committing.

**Phase 4. Document non-obvious cause.**

If the root cause is not obvious from the diff, write it down so
future readers — including future agents — can learn from it.
Decide based on the scope:

- **Bug-specific cause** (a subtle interaction, a race condition, a
  misunderstood API) → explain in the commit message body.
- **Pattern likely to recur** (an entire class of bugs, a
  project-wide gap) → add to `knowledge/<domain>/` via
  `continuous-learning`, or open an ADR if it changes an
  architectural choice.
- **Environment or process issue** (a CI misconfig, a dev-env
  quirk) → open an issue / RM and link from the commit.

Silent fixes ("it works now") that skip this phase are how the
same bug recurs six months later under a different symptom.

#### Task Routing (RM-034 reserved stub)

The v1 SKILL.md includes the same stub shape as `implement`:

> When a debugging task starts, consider whether domain-specific
> skills help — `dotnet` for .NET stack traces, the
> `frontend-specialist` role for UI-layer bugs, `tenant-scope-audit`
> for multi-tenant data-leak bugs, `money-review` for financial
> regressions.
>
> RM-034 will replace this paragraph with a decision matrix that
> auto-selects the right companion skill per bug based on files
> touched, error messages, and risk profile. Until RM-034 ships,
> the agent uses judgment and the installed-skills list.

The section heading (`## Task Routing`) matches `implement`'s stub
exactly so RM-034 can edit both in one pass.

#### Integration with other skills

- **`implement`** — features workflow. `debugging` handles bug
  triage up through the fix; the TDD loop inside `implement` is
  reused in Phase 3. They are paired members of the `starter`
  bundle.
- **`audit-all`** — pre-merge audit. Run after a bug fix before
  opening the PR, especially when the fix touches billing, tenant
  scope, or cross-stack contracts.
- **`continuous-learning`** — when a Phase 4 finding is a
  recurring pattern, capture it there.
- **`rules/common/*`** — always-on static rules. `debugging` never
  re-states rule content; references only.
- **`feature-lifecycle`** — if the bug has architectural
  implications, escalate to an ADR via `/octopus:doc-adr`.
- **`superpowers:systematic-debugging`** — when the superpowers
  plugin is installed, that skill wins per phase on the practices
  it covers. `debugging` still owns Phase 4 (Octopus-specific
  integration with `continuous-learning` / ADR).

#### Anti-patterns (explicit in SKILL.md)

The skill forbids, by name:

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
- Macro-commits that fold bisect artifacts, exploratory edits, the
  fix, and the regression test into one commit.

### Bundle membership

`bundles/starter.yml` gains `debugging`:

```yaml
name: starter
description: Baseline for any repo — ADRs, feature lifecycle, context budget, implementation workflow, debugging protocol.
category: foundation
skills:
  - adr
  - feature-lifecycle
  - context-budget
  - implement
  - debugging
```

`starter` is foundation-category (auto-included in every setup),
so `debugging` becomes universal. The skill stays stack-neutral;
nothing in it assumes a specific language or test runner.

### Slash command

`commands/debugging.md` is a thin dispatcher matching the pattern
established by `implement`:

```markdown
---
name: debugging
description: Walk the Octopus bug-fix protocol — reproduce, isolate, regression test, document.
---

# /octopus:debugging

## Purpose

The `debugging` skill is active by default on every bug-triage
task; this slash command drives it explicitly for a single bug the
user describes inline.

## Usage

```
/octopus:debugging <bug description or failing test name>
```

## Instructions

Invoke the `debugging` skill (`skills/debugging/SKILL.md`). The
skill owns the full four-phase workflow — do not reinterpret it
here.
```

### Wizard registration

`cli/lib/setup-wizard.sh` registers `debugging` in the skills items
array + hints + legend, inserted alphabetically after
`continuous-learning` and before `cross-stack-contract`.

### Migration / Backward Compatibility

- Additive: a new skill joining the existing `starter` bundle.
  Users who re-run `octopus setup` after upgrading get the skill;
  users who don't re-run keep the old setup (no breakage — the
  absence of `debugging` just means their agents do not have the
  protocol codified).
- No mandatory `.octopus.yml` changes.
- Test-file counts in `tests/test_bundles.sh` must increment:
  - Test 5 (starter fixture) expected count goes from 4 to 5.
  - Test 9 (full expansion) expected count goes from 9 to 10.
- CHANGELOG documents the addition.
- Composition with `superpowers:systematic-debugging` is
  non-breaking by design (more specific wins per phase, same rule
  as `implement` uses with `superpowers:test-driven-development`).

## Implementation Plan

1. `skills/debugging/SKILL.md` — frontmatter + Overview + When to
   Engage, with tests enforcing both.
2. SKILL.md — The Four Phases section with the four sub-sections
   from the content contract.
3. SKILL.md — Task Routing v1 stub naming RM-034.
4. SKILL.md — Integration + Anti-Patterns sections.
5. `commands/debugging.md` — thin dispatcher.
6. `bundles/starter.yml` — append `debugging` to skills list;
   update `description:` line.
7. `cli/lib/setup-wizard.sh` — register `debugging` in items +
   hints + legend (alphabetical — after `continuous-learning`,
   before `cross-stack-contract`).
8. `docs/features/debugging.md` — tutorial.
9. `docs/features/skills.md` — new row with `starter` bundle.
10. `README.md` — add `debugging` to the Available-skills comment.
11. `docs/roadmap.md` — move RM-031 from Backlog Cluster 4 into
    the Completed / Rejected table with a link to this spec.
12. `tests/test_debugging.sh` — structural tests covering
    frontmatter, all six sections, four phases named, task-routing
    section references RM-034, anti-patterns names key forbidden
    practices, bundle membership, command, wizard, README,
    skills.md row.
13. `tests/test_bundles.sh` — update starter fixture (Test 5 from
    4 skills to 5) and full-expansion count (Test 9 from 9 to 10).

## Context for Agents

**Knowledge modules**: none new.
**Implementing roles**: `backend-specialist` (bash + markdown),
`tech-writer` (tutorial + README).
**Related ADRs**: consider an ADR capturing the "active-by-default
workflow skill pair in `starter`" precedent — `implement` and
`debugging` together establish the pattern that future workflow
skills in `starter` may follow (e.g. `receiving-code-review`
belongs in `starter` too once RM-032 ships, if we agree; decision
deferred to that spec).
**Skills needed**: `adr`, `feature-lifecycle`.
**Bundle**: `starter` (existing) — append `debugging` alongside
`implement`.

**Constraints**:
- Pure markdown; no bash or python logic beyond documented
  commands the user or agent runs.
- `## Task Routing` heading must match `implement`'s exactly so
  RM-034 can extend both in one pass.
- The four phases must be named exactly `Phase 1. Reproduce
  deterministically`, `Phase 2. Isolate`, `Phase 3. Fix with a
  regression test first`, `Phase 4. Document non-obvious cause`
  (tests assert the header text).
- No duplication of `rules/common/*` content; reference only.
- `superpowers:systematic-debugging`, when installed, wins per
  phase on the practices it already covers.
- Skill stays stack-neutral — never mention a specific debugger,
  test runner, or language beyond illustrative `bash`/`pytest`/
  `dotnet test` examples in documentation.

## Testing Strategy

### Structural (`tests/test_debugging.sh`)

- `skills/debugging/SKILL.md` exists with correct frontmatter
  (`name: debugging`, `description:` present).
- All six section headers present: `## Overview`, `## When to
  Engage`, `## The Four Phases`, `## Task Routing`, `## Integration
  with Other Skills`, `## Anti-Patterns`.
- Four phase sub-sections named exactly: `### Phase 1. Reproduce
  deterministically`, `### Phase 2. Isolate`, `### Phase 3. Fix
  with a regression test first`, `### Phase 4. Document
  non-obvious cause`.
- Task-routing section contains the string `RM-034`.
- Anti-patterns section mentions `without reproducing`,
  `regression test`, `silent retry`, `feature flag`, and
  `macro-commit` (or `Macro-commits`).
- `commands/debugging.md` exists with `name: debugging` frontmatter.
- `bundles/starter.yml` lists `debugging`.
- Wizard items/hints/legend contain `debugging`.
- README Available list contains `debugging`.
- `docs/features/skills.md` has a `debugging` row with bundle
  `starter`.
- `docs/features/debugging.md` tutorial file exists.

### Extended `tests/test_bundles.sh`

- Test 5 (starter fixture): `expected_skills=(adr feature-lifecycle
  context-budget implement debugging)`; assertions expect 5 skills.
- Test 9 (full expansion): assertion `-eq 9` → `-eq 10`;
  `expected_skills=` array gains `debugging`.

### Manual / integration (not automated)

- Running `octopus setup` in a fresh repo emits
  `.claude/skills/debugging/SKILL.md` as a symlink.
- Invoking `/octopus:debugging "login endpoint returns 500 on
  empty email"` in a live session walks the four phases.
- When a bug report lands without invoking the slash command, the
  skill engages via its description on the first code-reading step.

## Risks

- **Overlap with `implement`'s TDD practice** — Phase 3 ("Fix with
  a regression test first") is TDD applied to a bug. Users might
  view this as duplication. Mitigation: the Integration section is
  explicit that `implement`'s TDD loop is reused in Phase 3; the
  skill describes what makes bug-driven TDD different (the red
  step comes from the bug report, not a new feature).
- **Stack-neutrality pressure** — users in a specific stack (e.g.
  .NET) will want stack-specific debugging guidance (lldb commands,
  Visual Studio breakpoints). Mitigation: the Non-Goals section
  forbids it in v1; stack-specific debugging belongs in the
  corresponding domain skill (`dotnet`, etc.), not here. A later
  RM can open composition hooks if the demand is real.
- **False-positive activation** — an agent might engage
  `debugging` when the user asks to read a stack trace they saw in
  a blog post, rather than a real bug in the repo. Mitigation: the
  `When to Engage` section narrows to tasks where the failure is
  inside the current working copy; read-only analysis is excluded.
- **Collision with `superpowers:systematic-debugging`** — both
  cover the same protocol. Mitigation: same rule as `implement`
  vs `superpowers:test-driven-development` — the more specific
  skill wins per phase when both are active. Integration section
  documents this explicitly.
- **Phase 4 rot** — "document non-obvious cause" is the step most
  likely to be skipped under time pressure. Mitigation: the phase
  is explicit in the skill body and in Anti-Patterns ("Silent
  fixes that skip this phase"); surfaces in future
  `continuous-learning` reviews.

## Changelog

- **2026-04-19** — Initial draft.
