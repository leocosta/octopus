---
name: review-pr
description: Walk the Octopus PR-feedback discipline — verify, ask for evidence, separate reasoned vs preference, never performative, clarify ambiguity.
---

---
description: Walk the Octopus PR-feedback discipline — verify, ask for evidence, separate reasoned vs preference, never performative, clarify ambiguity.
agent: code
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
