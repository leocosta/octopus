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
