---
name: respond-to-review
description: (Octopus) Walk the Octopus PR-feedback discipline — verify, ask for evidence, separate reasoned vs preference, never performative, clarify ambiguity.
agent: code
---

# /octopus:respond-to-review

## Purpose

The `respond-to-review` skill is active by default on every PR
feedback loop; this slash command drives it explicitly for a
single comment or thread the user describes inline.

This command is for **receiving** review feedback. To **write** a
review on someone else's PR, use `/octopus:pr-review`. To run a
self-review of uncommitted changes, use `/octopus:codereview`.

## Usage

```
/octopus:respond-to-review <pr-or-comment-ref>
```

## Instructions

Invoke the `respond-to-review` skill
(`skills/respond-to-review/SKILL.md`). The skill owns the full
five-rule workflow — do not reinterpret it here.
