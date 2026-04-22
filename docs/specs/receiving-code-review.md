# Spec: Receiving-Code-Review

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-19 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **RFC** | N/A |
| **Roadmap** | RM-032 |

## Problem Statement

PR feedback loops are a failure point for AI-assisted coding. When a
reviewer leaves a comment, the default assistant behavior is to make
some change that "addresses" the comment and move on — often without
verifying the critique is correct, without understanding the
reasoning, and without pushing back when the reviewer is wrong.

This produces two failure modes:

1. **Performative compliance** — agents change code just to close
   threads, without understanding why. The diff grows, the code
   quality drops, and the reviewer's actual concern stays
   unaddressed.
2. **Blind deference** — agents accept technically incorrect
   critiques as authoritative because they came from a reviewer.
   The code ends up with a regression introduced by a well-meaning
   but mistaken comment.

Both failures stem from the same gap: there is no codified protocol
for how an agent should *receive* review feedback before acting on
it. Octopus ships `pr-comments` (the command that walks the PR
thread) but not the discipline layer that governs how each comment
is processed.

Industry guidance converges on the same five rules used in the
existing `superpowers:receiving-code-review` skill: verify the
critique against the code, ask for evidence on generic comments,
separate reasoned feedback from preference, never make performative
changes, ask for clarification on ambiguity. RM-032 ships this
protocol as an Octopus-native skill so every repo using Octopus —
not just those that also install superpowers — has the workflow
available by default.

## Goals

- Ship a skill `receiving-code-review` that codifies a five-rule
  protocol for processing PR feedback: verify, ask for evidence,
  separate reasoned vs preference, never performative, ask before
  acting on ambiguity.
- Make the skill active by default in every Octopus-managed repo by
  adding it to the `starter` bundle (foundation category), joining
  `implement` (features) and `debugging` (bugs) as the third
  workflow skill.
- Preserve the SKILL.md shape used by `implement` and `debugging`
  (Overview, When to Engage, body sections, Task Routing reserved
  hook for RM-034, Integration with Other Skills, Anti-Patterns)
  so the three skills feel like a coherent trio.
- Compose cleanly with `/octopus:pr-comments` (the command that
  drives the feedback loop — the skill supplies the discipline, the
  command supplies the mechanics), with `implement` and `debugging`
  (they resume once the reviewer's ask is clear), and with
  `superpowers:receiving-code-review` when installed (composition
  rule: more specific skill wins per rule).

## Non-Goals

- Stack- or language-specific review guidance. The skill is
  stack-neutral; it describes discipline, not style.
- Replacing `/octopus:pr-review`. That command handles *writing* a
  review for someone else's PR. This skill handles *receiving* a
  review on your own PR. Different roles.
- Replacing `/octopus:pr-comments`. That command enumerates and
  organizes the feedback. This skill governs the response
  discipline per comment.
- Automated enforcement (a hook that refuses unless each comment
  was resolved with evidence). The skill is guidance, not a gate.
- Replacing `superpowers:receiving-code-review`. That skill, when
  installed, covers the same ground with more depth; this skill
  composes with it per the established `implement` / `debugging`
  precedent.
- RM-034 routing logic (the task-aware dispatcher). This spec
  reserves the section header for RM-034 to fill in.

## Design

### Overview

A pure-markdown skill at `skills/receiving-code-review/SKILL.md`,
same shape as `implement` and `debugging` — no new runtime, no new
dependencies. The body is organized into six sections. The skill
joins `bundles/starter.yml` next to `implement` and `debugging`,
completing the starter-foundation workflow trio (features / bugs /
review feedback).

The skill is active-by-default: Claude Code discovers it in
`.claude/skills/` and engages via its description whenever a task
involves processing PR feedback. Other agents receive the content
concatenated into their output file. A thin slash command
`/octopus:receiving-code-review [<pr or comment ref>]` exists for
explicit invocation.

### Detailed Design

#### Invocation

```
/octopus:receiving-code-review [<pr or comment ref>]
```

Most uses are implicit — the skill is active by default, and the
agent engages it when `/octopus:pr-comments <pr>` runs, when the
user shares a reviewer's comment, or when the current task starts
from "the reviewer said…". The slash command is for explicit mode
when auto-activation is missed or the user wants to drive the
five rules manually against a specific comment.

#### Skill structure

`skills/receiving-code-review/SKILL.md`:

```markdown
---
name: receiving-code-review
description: >
  The Octopus PR-feedback discipline — verify the critique, ask
  for evidence on generic comments, separate reasoned feedback
  from preference, never make performative changes, ask for
  clarification on ambiguity. Active by default on every PR
  feedback loop; pairs with /octopus:pr-comments (mechanics) and
  resumes implement/debugging for the actual code changes.
---

# Receiving-Code-Review Protocol

## Overview
<few sentences — complements pr-comments; five rules; pairs with
 implement/debugging>

## When to Engage
<triggers: PR feedback, pr-comments flow, reviewer message;
 NOT writing a review (that's pr-review)>

## The Five Rules
### 1. Verify the critique against the code
### 2. Ask for evidence on generic comments
### 3. Separate reasoned feedback from preference
### 4. Never make performative changes
### 5. Ask for clarification on ambiguity

## Task Routing (reserved for RM-034)
<stub only — named extension hook matching implement/debugging>

## Integration with Other Skills
<composition — pr-comments, implement, debugging,
 superpowers:receiving-code-review>

## Anti-Patterns
<explicit forbidden list>
```

Section content is filled during implementation, following the
content contract below.

#### Content contract — the five rules

**Rule 1. Verify the critique against the code.**

Before accepting any feedback as valid, read the code the reviewer
pointed at. Confirm the critique is actually correct — does the
code behave the way the reviewer claims? Does the concern apply?

If the reviewer is wrong (the code already handles the case, or
the claim doesn't match what the code does), say so. Politely and
with evidence: quote the specific lines that contradict the
critique. A reviewer who is wrong wants to know, not to be agreed
with.

If the reviewer is right, acknowledge it and proceed to the
remaining rules before making any change.

**Rule 2. Ask for evidence on generic comments.**

Generic critiques — "this is ugly", "seems wrong", "could be
better", "I don't like this" — cannot be acted on because they
don't describe a concrete concern. Respond asking for
specificity: "which part is ugly — the name, the structure, the
nesting?" or "what would you expect instead?".

Never infer what a generic comment probably means and change code
based on your inference. The reviewer has context you don't; ask
them to share it.

**Rule 3. Separate reasoned feedback from preference.**

Some critiques carry a technical reason (performance,
maintainability, consistency with the project, correctness,
security). Others are preference (aesthetic choice, personal
style, "I would write it differently").

Reasoned feedback gets weight — restate the reason in your
acknowledgement so the reviewer sees you understood it, then
decide whether to apply, push back with a counter-reason, or
propose an alternative.

Preference feedback is valid too, but it's a negotiation, not an
instruction. Say so honestly: "I'd stick with X because Y, but
happy to switch if you feel strongly." Don't treat preference as
authority.

**Rule 4. Never make performative changes.**

A performative change is one made to close a review thread
without understanding why. It's an anti-pattern because:

- The reviewer's actual concern stays unaddressed (you shipped
  something, but not what they asked for).
- The code gets worse (you edited something you didn't understand).
- The next similar comment creates the same pattern.

If you don't understand the feedback, engage Rule 2 (ask for
evidence) or Rule 5 (ask for clarification). If you understand
and disagree, engage Rule 3 (separate reasoned from preference
and push back on preference). Never change code with the goal of
closing a thread.

**Rule 5. Ask for clarification on ambiguity.**

When a critique is ambiguous — the words allow more than one
reading, the example points at several possible issues, the
suggestion has multiple implementations — ask before acting.

Examples of ambiguity to clarify:

- "This could be a helper" — which scope? A function in this
  file, a module-level helper, a shared utility?
- "Handle the error case" — which error case? What should the
  handler do?
- "Rename this" — to what?

Acting on your best guess creates a second round of feedback and
wastes the reviewer's time. One clarifying question saves that.

#### Task Routing (RM-034 reserved stub)

The v1 SKILL.md includes the same stub shape as `implement` and
`debugging`:

> When a code-review response starts, consider whether
> domain-specific skills help — `money-review` for comments on
> billing / tax / splits, `tenant-scope-audit` for multi-tenant
> data access concerns, `cross-stack-contract` for comments that
> touch both API and frontend, `debugging` when the reviewer
> points at a bug rather than a style issue.
>
> RM-034 will replace this paragraph with a decision matrix that
> auto-selects the right companion skill per comment based on
> the files it touches, the language of the comment, and the
> risk profile. Until RM-034 ships, the agent uses judgment and
> the installed-skills list.

The section heading (`## Task Routing`) matches `implement` and
`debugging` exactly so RM-034 can edit all three in one pass.

#### Integration with other skills

- **`/octopus:pr-comments`** — the command that drives the
  feedback loop. Mechanics (list comments, iterate, open threads)
  are in that command; discipline (how to process each comment)
  is in this skill. The two compose: `pr-comments` runs the loop,
  this skill governs each iteration.
- **`/octopus:pr-review`** — the command that *writes* a review
  for someone else's PR. Different role, different skill; this
  skill never engages on that flow.
- **`implement`** — when a comment asks for a code change (new
  feature, refactor, new test), `implement`'s five practices drive
  the edit itself. This skill ensures the change is the right
  change before `implement` runs.
- **`debugging`** — when a comment flags a bug the reviewer
  spotted, hand off to `debugging` (reproduce → isolate → fix
  with regression test → document). This skill still owns the
  verification step (Rule 1) before the handoff.
- **`rules/common/*`** — always-on static rules. This skill
  never re-states rule content; reference only.
- **`superpowers:receiving-code-review`** — when the superpowers
  plugin is installed, that skill wins per rule on the practices
  it covers. This skill still owns Octopus-native integration
  with `pr-comments` and the handoff to `implement` / `debugging`.

#### Anti-patterns (explicit in SKILL.md)

The skill forbids, by name:

- Accepting a critique as correct without reading the code it
  points at.
- Changing code to close a review thread without understanding
  the concern (performative compliance).
- Treating reviewer preference as a technical requirement.
- Acting on your inference of what a generic comment "probably"
  means instead of asking.
- Making a change and then discovering during the diff review
  that it doesn't match the reviewer's actual ask — should have
  been a clarifying question first.
- Pushing back on every comment without reading the code first
  (the opposite failure from blind deference).
- Deleting a reviewer's comment thread without resolving or
  acknowledging it.
- Batching a fix for one comment with unrelated changes — each
  comment's response gets its own commit so the reviewer can
  re-review atomically.

### Bundle membership

`bundles/starter.yml` gains `receiving-code-review`:

```yaml
name: starter
description: Baseline for any repo — ADRs, feature lifecycle, context budget, implementation workflow, debugging protocol, review-feedback discipline.
category: foundation
skills:
  - adr
  - feature-lifecycle
  - context-budget
  - implement
  - debugging
  - receiving-code-review
```

`starter` is foundation-category (auto-included in every setup),
so the skill becomes universal. The trio `implement` + `debugging`
+ `receiving-code-review` now covers the three common workflow
states — writing new code, fixing broken code, responding to
feedback on written code.

### Slash command

`commands/receiving-code-review.md` is a thin dispatcher matching
the pattern established by `implement` / `debugging`:

```markdown
---
name: receiving-code-review
description: Walk the Octopus PR-feedback discipline — verify, ask for evidence, separate reasoned vs preference, never performative, clarify ambiguity.
---

# /octopus:receiving-code-review

## Purpose

The `receiving-code-review` skill is active by default on every
PR feedback loop; this slash command drives it explicitly for a
single comment or thread the user describes inline.

## Usage

```
/octopus:receiving-code-review <pr-or-comment-ref>
```

## Instructions

Invoke the `receiving-code-review` skill
(`skills/receiving-code-review/SKILL.md`). The skill owns the
full five-rule workflow — do not reinterpret it here.
```

### Wizard registration

`cli/lib/setup-wizard.sh` registers `receiving-code-review` in the
skills items array + hints + legend, inserted alphabetically after
`plan-backlog-hygiene` and before `release-announce`.

### Migration / Backward Compatibility

- Additive: a new skill joining the existing `starter` bundle.
  Users who re-run `octopus setup` after upgrading get the skill;
  users who don't re-run keep the old setup (no breakage).
- No mandatory `.octopus.yml` changes.
- Test-file counts in `tests/test_bundles.sh` must increment:
  - Test 5 (starter fixture) expected count goes from 5 to 6.
  - Test 9 (full expansion) expected count goes from 10 to 11.
- CHANGELOG documents the addition.
- Composition with `superpowers:receiving-code-review` is
  non-breaking by design (more specific wins per rule, same
  precedent as `implement` with `superpowers:test-driven-development`
  and `debugging` with `superpowers:systematic-debugging`).

## Implementation Plan

1. `skills/receiving-code-review/SKILL.md` — frontmatter +
   Overview + When to Engage sections, with tests enforcing both.
2. SKILL.md — The Five Rules section with the five sub-sections
   from the content contract.
3. SKILL.md — Task Routing v1 stub naming RM-034.
4. SKILL.md — Integration + Anti-Patterns sections.
5. `commands/receiving-code-review.md` — thin dispatcher.
6. `bundles/starter.yml` — append `receiving-code-review` to
   skills list; update `description:` line.
7. `cli/lib/setup-wizard.sh` — register
   `receiving-code-review` in items + hints + legend (alphabetical
   — after `plan-backlog-hygiene`, before `release-announce`).
8. `docs/features/receiving-code-review.md` — tutorial.
9. `docs/features/skills.md` — new row with `starter` bundle.
10. `README.md` — add `receiving-code-review` to the
    Available-skills comment.
11. `docs/roadmap.md` — move RM-032 from Backlog Cluster 4 into
    the Completed / Rejected table with a link to this spec.
12. `tests/test_receiving_code_review.sh` — structural tests
    covering frontmatter, all six sections, five rules named,
    task-routing section references RM-034, anti-patterns names
    key forbidden practices, bundle membership, command, wizard,
    README, skills.md row.
13. `tests/test_bundles.sh` — update starter fixture (Test 5 from
    5 skills to 6) and full-expansion count (Test 9 from 10 to
    11).

## Context for Agents

**Knowledge modules**: none new.
**Implementing roles**: `backend-specialist` (bash + markdown),
`tech-writer` (tutorial + README).
**Related ADRs**: this is the third active-by-default workflow
skill in `starter` (following `implement` and `debugging`) — the
pattern is now firmly established; an ADR recording it is overdue
and would be worth filing as a side-RM.
**Skills needed**: `adr`, `feature-lifecycle`.
**Bundle**: `starter` (existing) — append
`receiving-code-review` alongside `implement` and `debugging`.

**Constraints**:
- Pure markdown; no bash or python logic beyond documented
  commands the user or agent runs.
- `## Task Routing` heading must match `implement` and
  `debugging` exactly so RM-034 can extend all three in one pass.
- The five rules must be named exactly `Rule 1. Verify the
  critique against the code`, `Rule 2. Ask for evidence on generic
  comments`, `Rule 3. Separate reasoned feedback from preference`,
  `Rule 4. Never make performative changes`, `Rule 5. Ask for
  clarification on ambiguity` (tests assert the header text).
- No duplication of `rules/common/*` content; reference only.
- `superpowers:receiving-code-review`, when installed, wins per
  rule on the practices it already covers.
- Skill stays stack-neutral — never mention a specific code
  review tool (GitHub PR, Gerrit, Phabricator) beyond illustrative
  examples referring to "a reviewer" generically.

## Testing Strategy

### Structural (`tests/test_receiving_code_review.sh`)

- `skills/receiving-code-review/SKILL.md` exists with correct
  frontmatter (`name: receiving-code-review`, `description:`
  present).
- All six section headers present: `## Overview`, `## When to
  Engage`, `## The Five Rules`, `## Task Routing`, `## Integration
  with Other Skills`, `## Anti-Patterns`.
- Five rule sub-sections named exactly: `### Rule 1. Verify the
  critique against the code`, `### Rule 2. Ask for evidence on
  generic comments`, `### Rule 3. Separate reasoned feedback from
  preference`, `### Rule 4. Never make performative changes`,
  `### Rule 5. Ask for clarification on ambiguity`.
- Task-routing section contains the string `RM-034`.
- Anti-patterns section mentions `performative`, `generic
  comment`, `preference`, `ambiguity`, and `batching` (or a
  variant — the test greps for key words).
- `commands/receiving-code-review.md` exists with
  `name: receiving-code-review` frontmatter.
- `bundles/starter.yml` lists `receiving-code-review`.
- Wizard items/hints/legend contain `receiving-code-review`.
- README Available list contains `receiving-code-review`.
- `docs/features/skills.md` has a `receiving-code-review` row
  with bundle `starter`.
- `docs/features/receiving-code-review.md` tutorial file exists.

### Extended `tests/test_bundles.sh`

- Test 5 (starter fixture): `expected_skills` gains
  `receiving-code-review`; assertions expect 6 skills.
- Test 9 (full expansion): assertion `-eq 10` → `-eq 11`;
  `expected_skills=` array gains `receiving-code-review`.

### Manual / integration (not automated)

- Running `octopus setup` in a fresh repo emits
  `.claude/skills/receiving-code-review/SKILL.md` as a symlink.
- Invoking `/octopus:pr-comments <n>` in a live session engages
  `receiving-code-review` for each comment iteration.
- Explicit invocation
  `/octopus:receiving-code-review "comment says 'this is ugly'"`
  triggers Rule 2 (ask for evidence).

## Risks

- **Overlap with `/octopus:pr-comments`** — some users might view
  the skill as redundant with the command. Mitigation: the
  Integration section is explicit about the split —
  `pr-comments` is mechanics (drive the loop), this skill is
  discipline (how to process each iteration). The two compose;
  neither replaces the other.
- **Performative compliance is hard to self-detect** — the skill
  forbids performative changes, but agents have a bias toward
  closing open threads. Mitigation: the Anti-Patterns section
  names the pattern explicitly; the When to Engage section links
  the trigger to the explicit five-rule walk before any edit.
- **Collision with
  `superpowers:receiving-code-review`** — both cover the same
  protocol. Mitigation: same rule as `implement` vs
  `superpowers:test-driven-development` — the more specific skill
  wins per rule when both are active. Integration section
  documents this explicitly.
- **Scope pressure toward tool integration** — users will ask
  for GitHub/GitLab-specific automation (auto-reply, auto-resolve).
  Mitigation: Non-Goals excludes it; a future RM can open a
  separate skill for tool-specific automation without contaminating
  this one.
- **"Ask for evidence" blocking progress** — if the agent asks for
  evidence on every generic comment, it can stall a fast review
  cycle. Mitigation: the rule is "ask before acting on inference",
  not "ask on every comment"; Rule 3 (preference) and Rule 5
  (ambiguity) handle graceful fast paths when evidence is
  self-evident from nearby context.

## Changelog

- **2026-04-19** — Initial draft.
