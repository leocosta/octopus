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
