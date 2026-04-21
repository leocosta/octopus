# Spec: `/octopus:doc-plan` — bite-sized implementation plan generator

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-21 |
| **Author** | Leonardo Costa |
| **Status** | Implemented (2026-04-21) |
| **RFC** | N/A |
| **Roadmap** | RM-036 |

## Problem Statement

`/octopus:doc-design` (RM-035) closed the spec-design gap —
designers now produce fleshed-out `docs/specs/<slug>.md`
files inside Octopus. The next rung of the ladder — turning
that spec into a **bite-sized, TDD-style implementation
plan** — still requires reaching for the external
`superpowers:writing-plans` skill. Teams that want a
self-sufficient Octopus need the second rung inside the
box.

A writing-plans equivalent should take a completed spec and
emit `docs/plans/<slug>.md` (or the equivalent project
convention) containing:

- Ordered tasks, each a discrete 2–5 minute action.
- Exact file paths per task (create / modify).
- Failing test first, then minimal implementation.
- Verification commands with expected output.
- Commit step at the end of each task.

## Goals

- Ship `/octopus:doc-plan <slug>` — command that reads
  `docs/specs/<slug>.md`, consults the spec's Implementation
  Plan (high-level), and produces `docs/plans/<slug>.md`
  with bite-sized tasks.
- Reuse the conversational-protocol DNA of `doc-design`:
  one-question-at-a-time, approval per task draft, HARD-GATE
  against writing code.
- Chain naturally from `doc-design`: the final message of a
  `doc-design` session already suggests
  `/octopus:doc-plan <slug>`; this RM makes that suggestion
  real.
- Ship the command in the `docs-discipline` bundle and
  register it in the wizard.

## Non-Goals

- Executing the plan. That is RM-037 (extend `implement` to
  walk a plan file). `doc-plan` only writes; execution
  comes later.
- Replacing the spec's own Implementation Plan section.
  The spec stays high-level ("what file / what change");
  the plan file is the bite-sized version
  ("test first / minimal implementation / verify / commit").
- Generating plans for specs that still have empty or
  `<!--` placeholders in their Implementation Plan section.
  The command aborts with a clear error pointing at the
  missing content.
- Auto-opening a worktree or branch. Terminal state is a
  committed plan file (same HARD-GATE discipline as
  `doc-design`).

## Design

### Overview

`/octopus:doc-plan <slug>` is a markdown command under
`commands/doc-plan.md` that drives a conversational session
to produce `docs/plans/<slug>.md` — a bite-sized, TDD-style
implementation plan derived from the spec at
`docs/specs/<slug>.md`.

The output format mirrors the established
`superpowers:writing-plans` vocabulary (header with
`REQUIRED SUB-SKILL` line, File Structure table, tasks as
`- [ ]` checklists with inline code, commit step per task).
Existing executors (`superpowers:executing-plans`,
`superpowers:subagent-driven-development`, and the future
`/octopus:implement` plan-walker in RM-037) consume this
format directly.

The output **path** is Octopus-native: `docs/plans/<slug>.md`
rather than `docs/superpowers/plans/`. This clarifies
ownership: plans produced by Octopus live under Octopus, and
external executors are pointed at `docs/plans/` when invoked.

Chaining:

- Run after `/octopus:doc-design` — the design command's
  final message suggests `/octopus:doc-plan <slug>`
  explicitly; this RM makes the suggestion real.
- Also runs standalone against any spec whose
  Implementation Plan section is populated.

HARD-GATE: `doc-plan` writes one plan file and commits it.
It does not execute tasks, does not create feature branches
(only the docs-only `docs/<slug>-plan` branch when starting
from `main`), and does not dispatch implementation skills.

### Detailed Design

**Single file: `commands/doc-plan.md`**

Follows the same `doc-*` packaging — no SKILL.md, just a
markdown command with an instructional protocol for the agent.

**Input / output contract:**

- Input: `docs/specs/<slug>.md` with a populated
  `## Implementation Plan` section (non-empty, no `<!--`
  placeholders). Abort with a helpful error pointing at the
  missing content otherwise.
- Output: `docs/plans/<slug>.md` (path is Octopus-native).
  Directory created if missing.

**Protocol (7 steps):**

```
Step 1 — Setup
  - Resolve <slug>; abort with usage if missing.
  - Validate spec exists and has populated Implementation
    Plan. Count the high-level items (P1..PN).

Step 2 — Context scan (silent)
  - git log --oneline -20
  - Spec's own Metadata (Roadmap, Author).
  - The spec's Implementation Plan items — read into memory
    as P1..PN.

Step 3 — Plan header
  - Generate the header block (Goal, Architecture line,
    Tech Stack, Spec link) inferred from the spec's metadata
    + Overview.
  - Show header + File Structure table draft to the user.
  - Approve / revise / skip.

Step 4 — Task decomposition (adaptive — rule C from design)
  For each P_i (i=1..N):
  - Default: emit one Task_i with 4–5 steps
    (failing test → run FAIL → implement → run PASS →
    commit).
  - Heuristic for "too big":
    * P_i touches ≥ 3 files, OR
    * P_i description mentions "rewrite", "refactor", "full",
      "introduce", or ≥ 3 distinct verbs.
    If triggered, ask: "P_i looks big (<signal>); break
    into <N> tasks? (y/n/custom)".
  - Heuristic for "too small":
    * P_i touches 1 file AND description ≤ 10 words AND
      previous task already touches related code.
    If triggered, ask: "P_i is trivial — fold into previous
    task? (y/n)".
  - Produce Task_i (or Task_i.a, Task_i.b, ...) following
    the TDD skeleton. Show to user; approve/revise.

Step 5 — Self-review (agent, no user interaction)
  - Scan generated plan for:
    * Placeholder red flags from writing-plans (TBD, TODO,
      "handle edge cases", "similar to task N").
    * Type / name consistency (function called X in Task 3
      must be X in Task 7, not Y).
    * Spec coverage — every spec Implementation Plan item
      has at least one task.
  - Fix inline. Report any gaps.

Step 6 — Ensure docs-only branch + commit
  Same pattern as doc-design Step 8:
    current=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current" == "main" || "$current" == "master" ]]; then
      git checkout -b "docs/<slug>-plan"
    fi
    git add docs/plans/<slug>.md
    git commit -m "docs(plans): <slug> — bite-sized plan from /octopus:doc-plan"

Step 7 — Close
  Print:
    Plan ready at docs/plans/<slug>.md
    (branch: docs/<slug>-plan).

    To execute, open a PR and merge, then run:
      /octopus:implement --plan docs/plans/<slug>.md
        (available once RM-037 ships)

    Or use superpowers:executing-plans or
    superpowers:subagent-driven-development against
    docs/plans/<slug>.md.

  STOP. HARD-GATE in effect.
```

**Plan file format (generated body):**

Header + body follow the existing `superpowers:writing-plans`
vocabulary. Exact skeleton (copied verbatim into the
generated file):

```markdown
# <SpecTitle> Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan
> task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** <derived from spec Overview>
**Architecture:** <1-2 sentences from spec Detailed Design>
**Tech Stack:** <derived from spec or asked>
**Spec:** `docs/specs/<slug>.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| ...from spec Implementation Plan... |

---

## Task 1: <name>

**Files:**
- Create: `exact/path`
- Modify: `exact/path:line-range`

- [ ] **Step 1: Write the failing test**

`<test code>`

- [ ] **Step 2: Run test to verify it fails**

Run: `<command>`
Expected: FAIL with "<reason>"

- [ ] **Step 3: ...**
```

**HARD-GATE behaviour (inherited from doc-design):**

- Docs-only branch (`docs/<slug>-plan`) auto-created when
  starting from `main` or `master`.
- No production-code edits, no test-file edits, no feature
  branch creation. Only writes `docs/plans/<slug>.md` and
  commits it.
- Agent aborts any mid-session request that drifts into
  implementation, pointing at the eventual
  `/octopus:implement --plan` (RM-037) instead.

### Migration / Backward Compatibility

<!-- How do existing users/systems transition? What breaks? -->

## Implementation Plan

1. **Freeze the plan-skeleton fixture.** Copy the
   `writing-plans` header + task structure verbatim into
   `skills/doc-plan/templates/plan-skeleton.md`. Source of
   truth for what `doc-plan` emits; downstream divergence
   surfaces as a test failure.
2. **Create `tests/test_doc_plan.sh`.** Structural tests:
   command frontmatter, 7-step protocol, HARD-GATE anchor,
   adaptive-decomposition keywords ("too big", "too small"),
   docs-only branch check, `docs/plans/<slug>.md` output
   path reference, bundle + wizard registration,
   plan-skeleton fixture existence, chain mention from
   `doc-design`. Depends on Step 1.
3. **Create `commands/doc-plan.md`.** The 7-step protocol
   (setup + coverage check, context scan, header draft,
   adaptive task decomposition, self-review, docs-only
   branch + commit, close). Copy the HARD-GATE +
   branch-auto-create pattern from `commands/doc-design.md`.
   Depends on Step 1.
4. **Modify `commands/doc-design.md` Step 7 handoff
   message** to drop "(available once RM-036 ships)" and
   suggest `/octopus:doc-plan <slug>` unconditionally.
   Depends on Step 3.
5. **Register `doc-plan` in `bundles/docs-discipline.yml`**
   and `cli/lib/setup-wizard.sh` (items array, hint line,
   display list). Mirrors the `doc-design` registration.
6. **Run full test suite** (`for t in tests/test_*.sh`)
   and confirm green.
7. **Update roadmap** — move RM-036 from Backlog to
   Completed, flip spec Status to `Implemented (<date>)`.

## Context for Agents

**Knowledge modules**: N/A (no domain knowledge; workflow
skill).
**Implementing roles**: tech-writer, backend-specialist
(bash).
**Related ADRs**: none; an ADR capturing the Cluster 5
workflow (design → plan → execute) is worth writing once
RM-037 ships.
**Skills needed**: `adr`, `feature-lifecycle`,
`plan-backlog-hygiene`.
**Bundle**: `docs-discipline (existing)` — mirrors
`doc-design`'s placement.

**Constraints**:
- Pure markdown command (no SKILL.md, no shell of its own).
- Output path is `docs/plans/<slug>.md` exclusively. Never
  writes under `docs/superpowers/plans/`.
- HARD-GATE: no code, no tests, no feature branches.
  Docs-only branch `docs/<slug>-plan` auto-created when
  starting from `main`/`master`.
- Plan body must match the frozen skeleton fixture
  byte-for-byte on structural elements (header, File
  Structure table, Task skeleton); the user-specific
  content (goal, tech stack, tasks) is free text.
- Idempotent: re-running `/octopus:doc-plan <slug>` on a
  spec whose plan already exists prompts before
  overwriting.

## Testing Strategy

- **Structural tests** in `tests/test_doc_plan.sh` (step 2
  of the plan):
  - `commands/doc-plan.md` frontmatter valid (`name`,
    `description`).
  - All seven protocol steps present (`Step 1` … `Step 7`).
  - HARD-GATE anchor string.
  - Adaptive-decomposition heuristic keywords ("too big",
    "too small", "break into", "fold into").
  - Docs-only branch creation guard (same grep patterns
    used in `test_doc_design.sh`).
  - `docs/plans/<slug>.md` output path referenced.
  - Plan-skeleton fixture exists at
    `skills/doc-plan/templates/plan-skeleton.md`.
  - `bundles/docs-discipline.yml` lists `doc-plan`.
  - `cli/lib/setup-wizard.sh` items + hints + display list
    include `doc-plan`.
  - `commands/doc-design.md` final message references
    `/octopus:doc-plan`.
- **Dog-food validation.** Run
  `/octopus:doc-plan bundle-diff-preview` and
  `/octopus:doc-plan post-merge-audit-hook` against the
  specs already landed (PRs #67 and #68) as the first
  real-world exercises. Verify the produced
  `docs/plans/*.md` match the skeleton and cover every
  Implementation Plan item.
- **Not tested** (same reasoning as `doc-design`):
  conversational quality, adaptive-heuristic accuracy,
  and task-body fitness for execution — all LLM-dependent,
  validated through dog-food.

## Risks

- **Heuristic noise.** The "too big" / "too small"
  decomposition prompts may interrupt a well-formatted spec
  with irrelevant questions. Mitigation: each heuristic
  AND-composes multiple signals (not OR), so only genuinely
  borderline items trigger. The user can answer `n` without
  penalty.
- **`writing-plans` vocabulary drift.** The generated plan
  format is captured from the current
  `superpowers:writing-plans` skeleton; if that schema
  evolves upstream, Octopus-produced plans go stale and
  executors may choke. Mitigation: freeze the vocabulary as
  a fixture (`skills/doc-plan/templates/plan-skeleton.md`)
  and assert, in tests, that generated output matches the
  fixture. Upstream drift is surfaced as a test failure
  rather than a silent divergence.
- **Spec-coverage false negatives.** Step 5 checks that
  every spec Implementation Plan item has at least one task.
  If the user verbally merged items during the session
  ("fold P3 into P4"), the naive count fails. Mitigation:
  emit as warning to stderr, not abort. User confirms when
  the merge was intentional.
- **Plan size explosion.** A spec with seven items, three of
  them "big", can yield 15–20 tasks — hard to review,
  costly to execute as a single batch. Mitigation: when
  total tasks exceed 15, emit a warning and suggest
  splitting the plan (`docs/plans/<slug>-part1.md` +
  `-part2.md`). The split is the user's call; `doc-plan`
  never splits automatically in one session.

## Changelog

<!-- Updated as the spec evolves -->
- **2026-04-21** — Initial draft (design session via
  `/octopus:doc-design` plan-B)
