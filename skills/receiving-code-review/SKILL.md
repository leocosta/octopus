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

This skill codifies the discipline side of processing review
feedback. `/octopus:pr-comments` owns the mechanics (walking the
thread, iterating comments); this skill owns the protocol for
what an agent does with each comment before acting on it.

`implement` covers writing new code; `debugging` covers fixing
broken code; `receiving-code-review` covers responding to
feedback on code that exists. The three form the `starter`
bundle's workflow trio — one skill per common working state.

The skill is stack-neutral. It describes a five-rule protocol,
not a specific tool or review platform. It never duplicates
`rules/common/*`. When the `superpowers:*` plugin is installed,
its `receiving-code-review` skill wins per rule on the practices
it already covers; this skill still owns Octopus-native
integration with `pr-comments` and the hand-offs to `implement`
and `debugging`.

## When to Engage

Engage whenever the task involves **processing PR feedback** —
a reviewer left a comment, `/octopus:pr-comments <n>` is running,
the user quotes a reviewer's message, a thread is open awaiting
response. Do not engage for:

- Writing a review for someone else's PR (that is
  `/octopus:pr-review`)
- Feature work or refactor that does not originate from a review
  comment (that is `implement`)
- Bug triage that does not originate from a review comment (that
  is `debugging`)
- Documentation-only changes with no code review attached

Engagement is implicit — Claude Code discovers this skill from
`.claude/skills/` and applies it automatically when the
description matches the task. Users who want explicit control
can invoke `/octopus:receiving-code-review <ref>` for a
single-comment walk.

## The Five Rules

The protocol is five rules applied to every comment before any
code change. Skip a rule only with a stated reason.

### Rule 1. Verify the critique against the code

Before accepting any feedback as valid, read the code the
reviewer pointed at. Confirm the critique is actually correct —
does the code behave the way the reviewer claims? Does the
concern apply?

If the reviewer is wrong (the code already handles the case, or
the claim doesn't match what the code does), say so. Politely
and with evidence: quote the specific lines that contradict the
critique. A reviewer who is wrong wants to know, not to be
agreed with.

If the reviewer is right, acknowledge it and proceed to the
remaining rules before making any change.

### Rule 2. Ask for evidence on generic comments

Generic critiques — "this is ugly", "seems wrong", "could be
better", "I don't like this" — cannot be acted on because they
don't describe a concrete concern. Respond asking for
specificity: "which part is ugly — the name, the structure,
the nesting?" or "what would you expect instead?".

Never infer what a generic comment probably means and change
code based on your inference. The reviewer has context you
don't; ask them to share it.

### Rule 3. Separate reasoned feedback from preference

Some critiques carry a technical reason (performance,
maintainability, consistency with the project, correctness,
security). Others are preference (aesthetic choice, personal
style, "I would write it differently").

Reasoned feedback gets weight — restate the reason in your
acknowledgement so the reviewer sees you understood it, then
decide whether to apply, push back with a counter-reason, or
propose an alternative.

Preference feedback is valid too, but it's a negotiation, not
an instruction. Say so honestly: "I'd stick with X because Y,
but happy to switch if you feel strongly." Don't treat
preference as authority.

### Rule 4. Never make performative changes

A performative change is one made to close a review thread
without understanding why. It's an anti-pattern because:

- The reviewer's actual concern stays unaddressed (you shipped
  something, but not what they asked for).
- The code gets worse (you edited something you didn't
  understand).
- The next similar comment creates the same pattern.

If you don't understand the feedback, engage Rule 2 (ask for
evidence) or Rule 5 (ask for clarification). If you understand
and disagree, engage Rule 3 (separate reasoned from preference
and push back on preference). Never change code with the goal
of closing a thread.

### Rule 5. Ask for clarification on ambiguity

When a critique is ambiguous — the words allow more than one
reading, the example points at several possible issues, the
suggestion has multiple implementations — ask before acting.

Examples of ambiguity to clarify:

- "This could be a helper" — which scope? A function in this
  file, a module-level helper, a shared utility?
- "Handle the error case" — which error case? What should the
  handler do?
- "Rename this" — to what?

Acting on your best guess creates a second round of feedback
and wastes the reviewer's time. One clarifying question saves
that.

## Task Routing

When a code-review response starts, consider whether
domain-specific skills help — `money-review` for comments on
billing / tax / splits, `tenant-scope-audit` for multi-tenant
data access concerns, `cross-stack-contract` for comments that
touch both API and frontend, `debugging` when the reviewer
points at a bug rather than a style issue.

RM-034 will replace this paragraph with a decision matrix that
auto-selects the right companion skill per comment based on
the files it touches, the language of the comment, and the
risk profile. Until RM-034 ships, the agent uses judgment and
the installed-skills list.

## Integration with Other Skills

- **`/octopus:pr-comments`** — the command that drives the
  feedback loop. Mechanics (list comments, iterate, open
  threads) are in that command; discipline (how to process
  each comment) is in this skill. The two compose —
  `pr-comments` runs the loop, this skill governs each
  iteration.
- **`/octopus:pr-review`** — writes a review for someone
  else's PR. Different role, different skill; this skill never
  engages on that flow.
- **`implement`** — when a comment asks for a code change
  (feature, refactor, new test), `implement`'s five practices
  drive the edit itself. This skill ensures the change is the
  right change before `implement` runs.
- **`debugging`** — when a comment flags a bug the reviewer
  spotted, hand off to `debugging` (reproduce → isolate → fix
  with regression test → document). This skill still owns
  Rule 1 (verify the critique) before the handoff.
- **`rules/common/*`** — always-on static rules. This skill
  never re-states rule content; reference only.
- **`superpowers:receiving-code-review`** — when the
  superpowers plugin is installed, that skill wins per rule on
  the practices it covers. This skill still owns Octopus-native
  integration with `pr-comments` and the handoffs to
  `implement` / `debugging`.

## Anti-Patterns

This skill forbids, by name:

- Accepting a critique as correct without reading the code it
  points at.
- Changing code to close a review thread without understanding
  the concern (performative compliance).
- Treating reviewer preference as a technical requirement.
- Acting on your inference of what a generic comment "probably"
  means instead of asking.
- Making a change and then discovering during the diff review
  that it doesn't match the reviewer's actual ask — should have
  been a clarifying question on ambiguity first.
- Pushing back on every comment without reading the code first
  (the opposite failure from blind deference).
- Deleting a reviewer's comment thread without resolving or
  acknowledging it.
- Batching a fix for one comment with unrelated changes — each
  comment's response gets its own commit so the reviewer can
  re-review atomically.
