---
name: money-review
description: Pre-merge audit of money-touching code — types, rounding, cents tests, env drift, idempotency, webhook signatures, fee disclosure.
---

---
description: Pre-merge audit of money-touching code — types, rounding, cents tests, env drift, idempotency, webhook signatures, fee disclosure.
agent: code
---

# /octopus:money-review

## Purpose

Scan the current branch (or a provided ref) for money-logic correctness
issues before merge. Produces a severity-tiered report (block / warn /
info) covering seven inspection families.

## Usage

```
/octopus:money-review [ref] [--base=main] [--write-report] [--only=<families>]
```

## Instructions

Invoke the `money-review` skill (`skills/money-review/SKILL.md`). The
skill owns the full workflow: ref/diff resolution, file discovery,
inspection family execution, and report rendering.

Do not reinterpret the skill here — dispatch to it.
