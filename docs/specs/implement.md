# Spec: Implement

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-19 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **RFC** | N/A |
| **Roadmap** | RM-030 |

## Problem Statement

Octopus ships a strong foundation for **what code should be** via
`rules/common/*`: coding style, quality gates, security rules,
testing principles, design patterns. These rules are always-on for
every configured agent and cover the static side of the craft.

What Octopus does not ship is a codified **how** — the process a
code assistant should follow while implementing. Recent guidance
from Boris Cherny's Claude Code tips and adjacent industry sources
treats the workflow itself as the unit that determines output
quality: TDD loops, plan-before-code gates, verification before
declaring work complete, a simplify pass after changes, commit
cadence, and graceful handling of cross-cutting / large-scale work.

Today these practices live in three disconnected places: a short
mention in the default CLAUDE.md template, the `superpowers:*`
skill family when the user opts into it, and the system prompt of
whichever agent is running. None of them is active-by-default
inside Octopus itself, so a new repo adopting Octopus gets the
rules but not the process — new users still need to learn
TDD/verification discipline elsewhere.

The roadmap's Cluster 4 (RM-030..RM-034) closes this gap. RM-030
is the core — the `implement` skill that encodes the universal
workflow. Cluster 4 lands in order: RM-030 (core), RM-031
(`debugging`), RM-032 (`receiving-code-review`), RM-033
(destructive-action guard hook), RM-034 (task routing inside
`implement`).

## Goals

- Ship a new skill `implement` that codifies five universal
  workflow practices: TDD loop, plan-before-code gate,
  verification-before-completion, simplify pass, commit cadence.
- Make the skill active by default in every Octopus-managed repo
  by adding it to the `starter` bundle (foundation category).
- Reserve an explicit "task routing" extension hook in the skill
  body so RM-034 can fill it without restructuring the SKILL.md.
- Stay compatible with Octopus's static `rules/common/*`. This
  skill is the process layer; the rules are the static layer.
  Neither duplicates the other.
- Cover the contract with other Octopus skills: compose with
  `feature-lifecycle` (docs), leave room for `debugging` (RM-031)
  and `receiving-code-review` (RM-032) to plug in cleanly.

## Non-Goals

- Automated enforcement (a commit hook that refuses unless TDD
  was followed, etc.). v1 is a guide, not a gate. A later RM can
  introduce optional hooks.
- Task routing itself — RM-034 covers it. v1 only reserves the
  hook location.
- Language- or framework-specific implementation guidance — that
  stays in `backend-patterns`, `dotnet`, `e2e-testing`, etc.
  `implement` is stack-neutral.
- Metrics or observability (how many tasks used TDD, etc.) —
  separate concern.
- Replacing `superpowers:test-driven-development`, `superpowers:
  systematic-debugging`, and friends. When a user enables those
  plugins, `implement` composes with them rather than competing.
  `implement` ships the Octopus-native baseline for users who do
  not pull in the superpowers plugin.

## Design

### Overview

A pure-markdown skill at `skills/implement/SKILL.md`. Same shape
as every other Octopus skill — no new runtime, no new deps. The
body is organized into six sections that together document the
workflow contract. The skill joins `bundles/starter.yml` so every
`octopus setup` run on a new repo activates it.

The skill is **active-by-default**: Claude Code discovers it in
`.claude/skills/` and invokes it via its description when any
implementation task begins. Other agents receive the content
concatenated into their output file. A thin slash command
`/octopus:implement [<task>]` exists for explicit invocation when
the auto-activation is missed or when a user wants to drive the
skill manually for a small task.

### Detailed Design

#### Invocation

```
/octopus:implement [<task description>]
```

Most uses are implicit — the skill is active by default, and the
agent engages it whenever a task involves editing code. The slash
command is for explicit mode: the user describes the task and the
agent walks the five-practice loop explicitly.

#### Skill structure

`skills/implement/SKILL.md`:

```markdown
---
name: implement
description: >
  The Octopus implementation workflow — TDD, plan-before-code,
  verification-before-completion, simplify pass, commit cadence.
  Active by default on every code task; pairs with rules/common/*
  (static rules) and feature-lifecycle (docs).
---

# Implement Protocol

## Overview
<what the skill does, in a few sentences>

## When to Engage
<trigger description — code-editing tasks only, distinct from
 read/explain-only flows>

## The Five Practices
### 1. TDD loop
### 2. Plan-before-code gate
### 3. Verification-before-completion
### 4. Simplify pass
### 5. Commit cadence

## Task Routing (reserved for RM-034)
<stub only in v1 — one paragraph pointing at the future extension>

## Integration with Other Skills
<composition rules — feature-lifecycle, debugging, audits, rules>

## Anti-Patterns
<explicit list of practices the skill forbids>
```

Every section carries enough detail that an agent reading SKILL.md
for the first time can apply the workflow without clarification.
Placeholders above are filled with concrete content in the
Implementation Plan section below.

#### The five practices (content contract)

**1. TDD loop.**

For any change with an observable behavior, follow red → green →
refactor → commit:

- Red: write a failing test for the behavior first. The test must
  actually fail when run (not merely "be written"); run it and
  confirm the failure mode before moving on.
- Green: write the minimal implementation that makes the test
  pass. No extra features, no "while I'm here" fixes.
- Refactor: simplify the code while tests stay green. Typical
  targets: extracted helpers, clearer names, removed duplication.
- Commit: each of these is an atomic commit — a failing test
  commit, an implementation commit, an optional refactor commit.
  Hooks must pass on each.

When the change has no testable behavior (e.g. a rename, a config
tweak, a doc update), skip TDD and move straight to the simplify
pass, but still split logically (rename commit, config commit, doc
commit) rather than macro-committing.

**2. Plan-before-code gate.**

For non-trivial tasks — any one of:

- touches more than 2 files
- introduces a new concept (new service, new bundle, new skill)
- has more than one viable approach

…the agent must present a short plan and wait for the user's
approval before editing code. The plan covers: what files change,
what the approach is, any trade-offs considered, and the
acceptance check. For larger work, escalate to `/octopus:doc-spec`
and let the feature-lifecycle skill handle it.

For genuinely trivial changes (single-file fix, single-line
config), the agent may proceed without a plan but must still
declare the intent in one sentence before editing.

**3. Verification-before-completion.**

Before declaring any unit of work "done", "complete", "fixed", or
"passing", run the relevant verification command and include the
output or a direct summary of it in the reply. Relevant commands
typically include:

- project test command (`pytest`, `npm test`, `dotnet test`,
  `bash tests/test_*.sh`, …)
- project typecheck (`tsc --noEmit`, `dotnet build --no-restore`,
  `mypy`, …)
- project formatter or linter when the change is code
- `git status` and `git log -n 1` when the change is a commit

Saying "it should work" without evidence is a protocol violation.
When verification is impractical (e.g. cannot run the test in the
current environment), state this explicitly: "could not run X in
this environment — should be verified by running Y before merge".

**4. Simplify pass.**

After the last green test passes and before committing, re-read
the changed code with the simplifier lens:

- Duplication across the new change (or duplication with existing
  code) → extract or consolidate
- Dead code, unused imports, or leftover scaffolding → remove
- Premature abstraction (interfaces, options bags, factory
  functions) with no second caller → inline
- Unclear names (`handleData`, `doIt`, generic abbreviations) →
  rename
- Comments that explain what the code does instead of why → rely
  on names; delete the comment or move the why-context to the
  commit message

A simplify pass that finds nothing to change is a valid outcome —
the point is the pass, not the diff.

**5. Commit cadence.**

One commit per logical step, not one macro-commit at the end of
the task:

- TDD produces 2–3 commits per behavior (red / green / optional
  refactor)
- Config changes get their own commit separate from code
- Doc updates get their own commit separate from code
- Each commit passes the project's pre-commit hooks (formatter,
  linter, typecheck). Never skip hooks with `--no-verify`.
- Each commit message follows the project's commit-conventions
  document (`core/commit-conventions.md`) — conventional commit
  prefix, clear scope, imperative voice.

#### Task routing (RM-034 hook — v1 stub)

The v1 SKILL.md includes the section verbatim:

> When an implementation task starts, consider whether any
> domain-specific skills should be consulted alongside the five
> core practices — `backend-patterns` or `dotnet` for server-side
> work, the `frontend-specialist` role for UI work, the
> `debugging` skill (when installed) for bug-fix flows, the
> `receiving-code-review` skill (when installed) for PR feedback
> loops.
>
> RM-034 will replace this paragraph with a decision matrix that
> auto-selects the right sub-skill per task based on the files
> touched, the prompt keywords, and the risk profile. Until
> RM-034 ships, the agent uses judgment and the
> installed-skills list.

This way the section already exists; RM-034 is an edit-in-place,
not a restructure.

#### Integration with other skills

- **`rules/common/*`** — rules are always-on and supply the
  static side ("what the code should be"). `implement` supplies
  the dynamic side ("how to get there"). Skills must never
  re-state rules content; references only.
- **`feature-lifecycle`** — governs docs (RFC → Spec → ADR →
  Knowledge). `implement` governs code. A task with both a docs
  ask and a code ask triggers both skills; the two compose
  without conflict.
- **`debugging` (RM-031, future)** — when a task starts from a
  bug report or a failing test, delegate to `debugging` for the
  reproduce → isolate → fix → regression steps. `implement`'s
  TDD loop still applies to the fix itself.
- **`receiving-code-review` (RM-032, future)** — PR feedback
  flows go through that skill; `implement` resumes for each
  implementation step the reviewer asks for.
- **Audit skills (`security-scan`, `money-review`,
  `tenant-scope-audit`, `cross-stack-contract`, `audit-all`)** —
  pre-merge review; `implement` is pre-audit.

#### Anti-patterns (explicit in SKILL.md)

The skill forbids, by name:

- Writing implementation code before the failing test (for
  testable behavior).
- "fix later" comments (`TODO`, `FIXME`) checked in. Either fix
  or remove; if a follow-up is required, open an issue/RM.
- Macro-commits covering multiple logical steps.
- `--no-verify` / `--no-gpg-sign` on commits. Fix the hook
  failure or ask.
- Declaring success ("it works", "tests pass", "done") without
  attaching verification evidence.
- Editing code in response to critique without understanding the
  critique — even non-performatively. Defer to RM-032.
- Premature abstraction (interfaces without a second caller,
  options bags for single callers).
- Duplicating content from `rules/common/*` into the skill body.
  References only.

### Bundle membership

`bundles/starter.yml` gains the skill:

```yaml
skills:
  - adr
  - feature-lifecycle
  - context-budget
  - implement
```

`starter` is the foundation category (auto-included, no persona
question), so every new repo's `octopus setup` ships with
`implement` active.

### Slash command

`commands/implement.md` is a thin dispatcher:

```markdown
---
name: implement
description: Walk the Octopus implementation workflow explicitly — TDD, plan-before-code, verification, simplify, commit cadence.
---

# /octopus:implement

## Purpose

The `implement` skill is active by default on every code task;
this slash command drives it explicitly for a single task the
user describes inline.

## Usage

```
/octopus:implement <task description>
```

## Instructions

Invoke the `implement` skill (`skills/implement/SKILL.md`). The
skill owns the full workflow — do not reinterpret it here.
```

### Wizard registration

`cli/lib/setup-wizard.sh` lists `implement` in the skills items
array + hints + legend, inserted alphabetically between
`feature-to-market` and `money-review`.

### Migration / Backward Compatibility

- Additive: a new skill joining an existing bundle. Users who
  re-run `octopus setup` after upgrading get the skill; users
  who don't, keep the old setup.
- Zero conflict with `superpowers:test-driven-development`,
  `superpowers:systematic-debugging`,
  `superpowers:verification-before-completion`, etc. When both
  plugins are enabled, the Octopus `implement` skill defers to
  those on the practices they already cover and fills the gaps
  on the others. The composition rule: the more specific skill
  wins per practice (e.g. the superpowers TDD skill covers TDD;
  `implement` still owns the other four practices).
- No mandatory new fields in `.octopus.yml`.
- CHANGELOG documents the addition.

## Implementation Plan

1. `skills/implement/SKILL.md` — frontmatter + Overview + When
   to Engage sections, with tests enforcing both.
2. SKILL.md — The Five Practices section with the five
   sub-sections described above.
3. SKILL.md — Task Routing v1 stub section naming RM-034.
4. SKILL.md — Integration + Anti-Patterns sections.
5. `commands/implement.md` — thin dispatcher.
6. `bundles/starter.yml` — add `implement` to skills list.
7. `cli/lib/setup-wizard.sh` — register `implement` in items +
   hints + legend.
8. `docs/features/implement.md` — tutorial.
9. `docs/features/skills.md` — new row with `starter` bundle.
10. `README.md` — add `implement` to the Available-skills comment.
11. `docs/roadmap.md` — move RM-030 into Completed with link to
    this spec.
12. `tests/test_implement.sh` — structural tests covering
    frontmatter, all six sections present, five practices named,
    task-routing section references RM-034, bundle membership,
    command file, wizard registration, README, skills.md row.
13. Extend `tests/test_bundles.sh` to assert `starter` expansion
    now yields four skills instead of three.

## Context for Agents

**Knowledge modules**: none new.
**Implementing roles**: `backend-specialist` (bash + skill
markdown), `tech-writer` (tutorial + README).
**Related ADRs**: worth considering an ADR for the
"active-by-default skill in the foundation bundle" pattern —
it's a precedent the future `debugging` and
`receiving-code-review` skills will reuse.
**Skills needed**: `adr`, `feature-lifecycle`.
**Bundle**: `starter` (existing) — append `implement` to the
bundle's skills list.

**Constraints**:
- Pure markdown. No bash or python logic in the skill body
  beyond documentation of commands the user or agent runs.
- Skill body must not duplicate `rules/common/*` content;
  references only.
- `## Task Routing` section must be present in v1 with the
  stub wording (named RM-034) so the section name is stable.
- `superpowers:*` skills, when installed, override Octopus's
  coverage on the practices they already own. Document this in
  `## Integration with Other Skills`.
- The slash command is optional for users; discovery through
  auto-activation is the primary path.

## Testing Strategy

### Structural (`tests/test_implement.sh`)

- `skills/implement/SKILL.md` exists with correct frontmatter
  (`name: implement`, `description:` present).
- Six section headers present: `## Overview`, `## When to
  Engage`, `## The Five Practices`, `## Task Routing`,
  `## Integration with Other Skills`, `## Anti-Patterns`.
- Five practice sub-sections named exactly: `### 1. TDD loop`,
  `### 2. Plan-before-code gate`, `### 3. Verification-before-
  completion`, `### 4. Simplify pass`, `### 5. Commit cadence`.
- Task-routing section contains the string `RM-034`.
- Anti-patterns section mentions at least `--no-verify`,
  macro-commit, premature abstraction, rules duplication.
- `commands/implement.md` exists with `name: implement`
  frontmatter.
- `bundles/starter.yml` lists `implement`.
- Wizard items/hints/legend contain `implement`.
- README Available list contains `implement`.
- `docs/features/skills.md` has an `implement` row with bundle
  `starter`.

### Extended `tests/test_bundles.sh`

- `starter` expansion now yields 4 skills
  (`adr, feature-lifecycle, context-budget, implement`).
- Full `bundles-only manifest expands to full component lists`
  assertion updates its expected count (previously 8 after
  starter + quality-gates + depends_on; now 9).

### Manual / integration (not automated)

- Running `octopus setup` in a fresh repo emits
  `.claude/skills/implement/SKILL.md` as a symlink.
- Invoking `/octopus:implement "add a greeting endpoint"` in a
  live Claude Code session triggers the five-practice walk.

## Risks

- **Rules / skill overlap drift** — `rules/common/testing.md`
  already says "behavior > implementation, AAA, coverage";
  `implement`'s TDD practice says "write failing test first".
  These are complementary (static vs dynamic) but could look
  redundant at a glance. Mitigation: Integration section is
  explicit about the split; anti-patterns section forbids
  content duplication.
- **Active-by-default noise** — the skill engaging on every
  small tweak (a typo fix, a comment change) will annoy users.
  Mitigation: the `When to Engage` section is deliberately
  narrow (code-editing tasks with observable behavior); the
  slash command exists for users who want explicit engagement
  and nothing else.
- **Routing stub going stale** — v1 ships a paragraph that names
  RM-034; if RM-034 never lands, the pointer rots. Mitigation:
  the paragraph is framed as "until RM-034 ships, the agent
  uses judgment" — it degrades gracefully even if RM-034 is
  deferred.
- **Competing with `superpowers:*`** — users on the superpowers
  plugin already have TDD, systematic-debugging, and
  verification-before-completion skills. `implement` duplicating
  those would feel noisy. Mitigation: Integration section
  defers to superpowers skills when installed.
- **Scope creep into RM-031/032/033** — the Anti-Patterns list
  mentions deferring to `receiving-code-review` (RM-032) and
  `debugging` (RM-031). If those RMs slip, users will ask
  `implement` to cover those flows. Mitigation: spec keeps
  those strictly out of scope; a future RM can extend
  `implement` if the community prefers one skill to three.

## Changelog

- **2026-04-19** — Initial draft.
