---
name: map-system
description: (Octopus) Produce a higher-level map of the relevant modules and their callers in the project's domain vocabulary — manual-invocation only.
---

---
description: (Octopus) Produce a higher-level map of the relevant modules and their callers in the project's domain vocabulary — manual-invocation only.
agent: code
---

# /octopus:map-system

## Purpose

The `map-system` skill is **manual-invocation only** by design — it
does not engage automatically from task signals. This slash command
is the canonical way to trigger it when the user (or a delegating
agent) needs a one-shot map of an unfamiliar area of the code.

## Usage

```
/octopus:map-system <area or question>
```

## Instructions

Invoke the `map-system` skill (`skills/map-system/SKILL.md`). The
skill owns the abstraction-level rule (always one level above the
question), the domain-vocabulary rule (CONTEXT.md terms only), and
the one-screen output budget — do not reinterpret here.

If `CONTEXT.md` is missing, surface that to the user — the map will
use code identifiers as a fallback, but the gap should be visible.
