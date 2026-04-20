---
name: debugging
description: Walk the Octopus bug-fix protocol — reproduce, isolate, regression test, document non-obvious cause.
---

# /octopus:debugging

## Purpose

The `debugging` skill is active by default on every bug-triage
task; this slash command drives it explicitly for a single bug
the user describes inline.

## Usage

```
/octopus:debugging <bug description or failing test name>
```

## Instructions

Invoke the `debugging` skill (`skills/debugging/SKILL.md`). The
skill owns the full four-phase workflow — do not reinterpret it
here.
