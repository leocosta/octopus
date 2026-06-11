---
name: audit-style
model: haiku
description: >
  Signal-only review flagging code that violates the team's design rules
  (exceptions gate, patterns, coding-style, active stack rules) and over-
  engineering (premature abstraction, speculative hierarchy, DRY-before-three)
  — what a formatter or type-checker can't see. Never blocks; runs on demand
  via codereview/pr-review/implement. The house-rules complement to native
  simplify.
triggers:
  keywords: ["audit style", "style check", "over-engineering", "rule violation", "design quality", "premature abstraction"]
---

# Design-Rules Style Audit

## Overview

A formatter, a type checker, and a secret scanner judge **syntax** — and
the native `simplify` applies generic taste. Neither knows the team's
*opinionated* rules: that a custom exception must clear a gate before it
earns its existence, that an expected failure should be a typed result and
not a throw, that a boolean parameter wants an options object, that
abstraction is a cost to be paid only at the third occurrence. Those are
the rules a human agreed to and wrote down; the only thing that can judge
conformance is a reader holding the rules in one hand and the diff in the
other.

`audit-style` is that reader. It loads the design rules the repo already
ships and confronts the diff against them, emitting two kinds of finding:

- **`rule-violation`** — a construct the diff introduces that contradicts a
  stated rule: a custom exception that fails the gate, a throw where a typed
  result is called for, a boolean parameter, a magic number, a missing guard
  clause, business logic leaking into a repository, a swallowed exception.
- **`over-engineering`** — abstraction the rules explicitly call a cost:
  premature abstraction, a speculative subtype hierarchy "for the future",
  DRY applied before three occurrences, an indirection layer for a problem
  that does not exist yet. This is the dimension the native `simplify`
  structurally cannot produce — it optimizes for *less code* and may itself
  introduce the abstraction the rules forbid. `audit-style` is the reader
  that knows when **not** to simplify.

The skill is **signal-only**: it never blocks a commit, a task, or a merge.
A design verdict is a judgment call, and blocking on a judgment call is
worse than the problem it solves. It reports; the human decides.

## When to Engage

Engage when:

- A review flow invokes it — `codereview`, `pr-review`, or the `implement`
  simplify pass — to check the diff against the house rules before merge.
- A reviewer wants a rules-grounded second read that the generic `simplify`
  cannot give, especially to catch over-engineering.

Do **not** engage for:

- Syntactic concerns — formatting, type errors, secrets. Those are the
  `guardrails` bundle's job (pre-commit + loop-level hooks) and they
  *block*; this skill does not duplicate them.
- The domain source of truth — invented conventions and unsupported domain
  facts are `audit-grounding`'s job. `audit-style` judges the diff against
  the *coding rules*, not the *domain*.
- Generic, rule-agnostic cleanup — that is the native `simplify`. This skill
  adds the house-rules layer on top; it does not replace it.

## The Source of Truth

Load, in order, and degrade gracefully when an artifact is absent:

1. **`exceptions.md`** — the custom-exception gate (the
   default-to-stdlib rule, the G1/G2/G3 justification gate, the forbidden
   smells) and the "delete the class when the last catch site goes" rule.
   The primary reference for exception-related `rule-violation` findings.
2. **`rules/common/patterns.md`** — the architecture conventions: Result
   pattern for expected failures, repository/service separation, guard
   clauses, event-handling idioms.
3. **`rules/common/coding-style.md`** — naming, code-structure, and the
   anti-pattern catalogue (god functions, magic numbers, boolean
   parameters, premature abstraction, copy-paste).
4. **The active stack rules** — any `rules/<stack>/*.md` (e.g.
   `rules/csharp/error-handling.md`) matching the languages the diff
   touches, plus a project-local `*.local.md` override where present.

When a rules file is missing, fall back to the ones present and report the
absence as an `info` note so the team knows the audit was partial.

## Protocol

1. **Scope the diff.** Use the same ref discovery the other `audit-*` skills
   use (working tree, a branch, or a PR ref). Restrict attention to changed
   lines and the files they touch.
2. **Load the rules** in the order above, selecting the stack rules that
   match the changed files' languages.
3. **Hunt rule violations.** For each construct the diff introduces, check
   it against the rules. A new `class XException` is checked against the
   exceptions gate (is there a catch site of this type? a structured field
   an operator reads? does a stdlib type fail to express it?); a throw on an
   expected failure against the Result-pattern rule; a boolean parameter, a
   magic number, a deeply nested conditional, business logic in a repository
   against `coding-style.md`/`patterns.md`. Emit a `rule-violation` finding
   citing the diff location and the exact rule it breaks.
4. **Hunt over-engineering.** For each abstraction the diff adds — a new
   interface with one implementation, a subtype hierarchy with empty
   members, an extraction at the second occurrence, an indirection with no
   present caller — check it against the YAGNI / "three occurrences before
   extracting" / "speculative hierarchy is forbidden" rules. Emit an
   `over-engineering` finding. When in doubt, prefer flagging the
   abstraction over flagging its absence — the rules treat abstraction as
   the cost.
5. **Report.** Emit findings in the same severity-tiered shape as
   `audit-all`, but capped at `warn`/`info` — **never `block`**. State
   explicitly in the report header that the audit is signal-only.

## Report Shape

Mirror `audit-all`'s tiered report, with the blocking tier disabled:

- **`warn`** — a clear divergence from a stated rule the human should
  resolve before merge (an exception that fails the gate; a speculative
  hierarchy; a swallowed exception).
- **`info`** — a weaker signal or a partial-rules note (a borderline
  abstraction that may be justified; a magic number in throwaway code; a
  rules file missing).

Each finding names the diff location, the finding type (`rule-violation` /
`over-engineering`), the rule it was checked against (file + the specific
clause), and a one-line "what to change". End with a trailer line:
`audit-style: 0 block, N warn, N info`. The audit emits no `block` tier by
design.

## Anti-Patterns

- Blocking on a finding — forbidden; this skill is signal-only.
- Flagging syntactic issues the `guardrails` bundle already blocks, or
  domain divergences `audit-grounding` owns.
- Re-applying generic taste the native `simplify` already covers — only
  surface what a rule actually says.
- Manufacturing a violation when the rules do not cover the construct — say
  "not covered" (`info`), do not invent a `warn`.
- Recommending an abstraction the rules call premature — this skill exists
  partly to push back on over-abstraction, not to add it.
- Editing the rules or the diff — the skill is read-only.

## Integration with Other Skills

- **native `simplify`** — applies generic, rule-agnostic taste and edits the
  code. `audit-style` runs the house-rules layer on top and only signals.
  Division of labour, not competition.
- **`audit-grounding`** — sibling signal-only audit; it judges the diff
  against the **domain** source of truth, this one against the **coding
  rules**. Same report shape, same never-block discipline.
- **`refactor-deepen`** — *deepens* design (improves architecture);
  `audit-style` *signals* where the diff diverges from the rules.
- **`codereview` / `pr-review` / `implement`** — the orchestrators that
  invoke this skill; it has no Stop hook of its own.
- **`continuous-learning` / `review-proposals`** — recurring `audit-style`
  findings feed the existing knowledge loop as rule / CLAUDE.md candidates,
  so a violation the team keeps making is promoted into a rule rather than
  re-flagged forever.
- **`guardrails` bundle** — owns the syntactic, blocking layer this skill
  deliberately does not duplicate.
## Model tier

This audit is mechanical — it pattern-matches a diff against a fixed
checklist, not deep reasoning. Run it on the **cheapest model tier**
(`--model haiku` / each assistant's cheapest). Reserve frontier models
for the `architect`/`dba`/`security` roles that adjudicate the findings
(RM-130).
