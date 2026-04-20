---
name: implement
description: Walk the Octopus implementation workflow explicitly — TDD, plan-before-code, verification, simplify, commit cadence.
---

---
description: Walk the Octopus implementation workflow explicitly — TDD, plan-before-code, verification, simplify, commit cadence.
agent: code
---

# /octopus:implement

## Purpose

The `implement` skill is active by default on every code task;
this slash command drives it explicitly for a single task the
user describes inline.

## Usage

```
/octopus:implement <task description>
```

## Instructions

Invoke the `implement` skill (`skills/implement/SKILL.md`). The
skill owns the full workflow — do not reinterpret it here.
