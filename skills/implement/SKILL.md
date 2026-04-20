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

This skill codifies the process side of coding inside Octopus.
`rules/common/*` already covers the static rules (what the code
should be); this skill covers the workflow (how to get there).
It is active by default on every code-editing task so the five
practices below apply without opt-in.

The skill is stack-neutral. It does not replace language-specific
skills (`backend-patterns`, `dotnet`, `e2e-testing`, …) — it
composes with them. It does not replace the `superpowers:*` skill
family when the user installs those; see `## Integration with
Other Skills` for the composition rules.

## When to Engage

Engage whenever the task involves **editing code** — adding a
feature, fixing a bug, refactoring, renaming a symbol, updating a
config, writing tests. Do not engage for:

- Read-only analysis (explain this function, find the caller of X)
- Documentation-only changes with no code attached (those go
  through `feature-lifecycle`)
- Research / brainstorming (pair with `superpowers:brainstorming`
  or the Octopus `/doc-research` command instead)

Engagement is implicit — Claude Code discovers this skill from
`.claude/skills/` and applies it automatically when the description
matches the task. Users who want explicit control can invoke
`/octopus:implement <task>` for a single-task walk.

## The Five Practices

The workflow is five practices applied in order on every task.
They are guidance, not a mechanical gate — skip a practice only
with a stated reason, and always prefer the full loop when the
change has observable behavior.

### 1. TDD loop

For any change with observable behavior, follow
red → green → refactor → commit:

- **Red.** Write a failing test for the new behavior first. Run
  it and confirm the failure mode before moving on (the test
  must actually fail, not merely "be written").
- **Green.** Write the minimal implementation that makes the test
  pass. No extra features, no "while I'm here" fixes.
- **Refactor.** Simplify the code while tests stay green.
  Typical targets: extracted helpers, clearer names, removed
  duplication.
- **Commit.** Atomic commits at each step (failing-test commit,
  implementation commit, optional refactor commit). Hooks must
  pass on each commit.

When the change has no testable behavior (a rename, a config
tweak, a doc update), skip TDD and move straight to the simplify
pass — but still split logically (rename commit / config commit
/ doc commit) rather than macro-committing.

### 2. Plan-before-code gate

For non-trivial tasks — any one of:

- touches more than 2 files
- introduces a new concept (new service, new bundle, new skill)
- has more than one viable approach

…present a short plan and wait for the user's approval before
editing code. The plan covers: what files change, the approach,
trade-offs considered, and an acceptance check. For larger work,
escalate to `/octopus:doc-spec` and let `feature-lifecycle` drive.

For genuinely trivial changes (single-file fix, single-line
config), proceed without a plan but still declare the intent in
one sentence before editing.

### 3. Verification-before-completion

Before declaring any unit of work "done", "complete", "fixed", or
"passing", run the relevant verification command and include the
output (or a direct summary of it) in the reply:

- Project test command (`pytest`, `npm test`, `dotnet test`,
  `bash tests/test_*.sh`, …)
- Project typecheck (`tsc --noEmit`, `dotnet build --no-restore`,
  `mypy`, …)
- Project formatter or linter when the change is code
- `git status` and `git log -n 1` when the change is a commit

"It should work" without evidence is a protocol violation. When
verification is impractical in the current environment, state
that explicitly: "could not run X here — should be verified by
running Y before merge".

### 4. Simplify pass

After the last green test passes and before committing, re-read
the changed code with the simplifier lens:

- Duplication across the new change (or with existing code) —
  extract or consolidate.
- Dead code, unused imports, leftover scaffolding — remove.
- Premature abstraction (interfaces, options bags, factory
  functions) with no second caller — inline.
- Unclear names (`handleData`, `doIt`, generic abbreviations) —
  rename.
- Comments that explain what the code does instead of why —
  rely on names; delete the comment or move the why-context to
  the commit message.

A simplify pass that finds nothing is a valid outcome — the point
is the pass, not the diff.

### 5. Commit cadence

One commit per logical step, not one macro-commit at the end:

- TDD produces 2–3 commits per behavior (red / green / optional
  refactor).
- Config changes get their own commit separate from code.
- Doc updates get their own commit separate from code.
- Each commit passes the project's pre-commit hooks (formatter,
  linter, typecheck). Never skip hooks with `--no-verify`.
- Each commit message follows `core/commit-conventions.md` —
  conventional-commit prefix, clear scope, imperative voice.

## Task Routing

When an implementation task starts, consider whether any
domain-specific skills should be consulted alongside the five
core practices — `backend-patterns` or `dotnet` for server-side
work, the `frontend-specialist` role for UI work, the
`debugging` skill (when installed) for bug-fix flows, the
`receiving-code-review` skill (when installed) for PR feedback
loops.

RM-034 will replace this paragraph with a decision matrix that
auto-selects the right sub-skill per task based on the files
touched, the prompt keywords, and the risk profile. Until
RM-034 ships, the agent uses judgment and the installed-skills
list.

## Integration with Other Skills

- **`rules/common/*`** — always-on static rules ("what the code
  should be"). This skill supplies the dynamic side ("how to get
  there"). Never re-state rule content here; reference only.
- **`feature-lifecycle`** — governs documentation (RFC → Spec →
  ADR → Knowledge). `implement` governs code. A task with both
  a docs ask and a code ask triggers both skills; they compose
  without conflict.
- **`debugging` (RM-031, future)** — when a task starts from a
  bug report or a failing test, delegate to `debugging` for the
  reproduce → isolate → fix → regression flow. The TDD loop in
  this skill still applies to the fix itself.
- **`receiving-code-review` (RM-032, future)** — PR feedback
  loops go through that skill; `implement` resumes for each
  implementation step the reviewer asks for.
- **Audit skills** (`security-scan`, `money-review`,
  `tenant-scope-audit`, `cross-stack-contract`, `audit-all`) —
  pre-merge review. `implement` is pre-audit.
- **`superpowers:*` skills** — when the user has the
  superpowers plugin installed, its skills (TDD, systematic
  debugging, verification-before-completion, …) cover the same
  ground as some practices here. Composition rule: the more
  specific skill wins per practice. If
  `superpowers:test-driven-development` is active, it drives
  TDD; `implement` still owns the other four practices.

## Anti-Patterns

This skill forbids, by name:

- Writing implementation code before the failing test (for
  testable behavior).
- "fix later" comments (`TODO`, `FIXME`) checked in — either fix
  now or open a tracked issue / RM before merging.
- Macro-commits covering multiple logical steps.
- `--no-verify` / `--no-gpg-sign` on commits. Fix the hook
  failure or ask.
- Declaring success ("it works", "tests pass", "done") without
  attaching verification evidence.
- Editing code in response to critique without understanding the
  critique. Defer to `receiving-code-review` (RM-032) when it
  ships.
- Premature abstraction — interfaces, options bags, or factory
  functions without a second caller.
- Duplicating content from `rules/common/*` into this skill body.
  References only.
