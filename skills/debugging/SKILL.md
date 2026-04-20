---
name: debugging
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
