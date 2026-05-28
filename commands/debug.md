---
name: debug
description: (Octopus) Walk the Octopus bug-fix protocol — reproduce, isolate, regression test, document non-obvious cause.
---

# /octopus:debug

## Purpose

The `debug` skill is active by default on every bug-triage
task; this slash command drives it explicitly for a single bug
the user describes inline.

## Usage

```
/octopus:debug <bug description or failing test name>
```

## Instructions

Invoke the `debug` skill (`skills/debug/SKILL.md`). The
skill owns the full four-phase workflow — do not reinterpret it
here.
