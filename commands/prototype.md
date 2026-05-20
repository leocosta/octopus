---
name: prototype
description: (Octopus) Build a throwaway prototype to answer one design question — logic branch (terminal app) or UI branch (variants on one route).
---

---
description: (Octopus) Build a throwaway prototype to answer one design question — logic branch (terminal app) or UI branch (variants on one route).
agent: code
---

# /octopus:prototype

## Purpose

The `prototype` skill defines the throwaway-code discipline; this
slash command drives it explicitly when the user wants to start a
prototype now and has a specific design question in mind.

## Usage

```
/octopus:prototype <one-sentence question to answer>
```

## Instructions

Invoke the `prototype` skill (`skills/prototype/SKILL.md`). The skill
owns the bifurcation gate (logic vs UI), the layout rules, the
no-persistence default, and the capture-then-delete protocol — do
not reinterpret here.

If the user did not state a question, refuse and ask for one. A
prototype without a question is a half-built feature.
