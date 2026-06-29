---
name: council
description: (Octopus) Run one high-stakes decision through a 5-lens council — parallel advisors, anonymous peer review, chairman verdict (agreements, clashes, blind spots, recommendation, first step).
---

# /octopus:council

## Purpose

Pressure-test one decision from five independent thinking lenses, have them
peer-review each other anonymously, and return a single synthesised verdict —
without leaving the current session. Read-only: it writes nothing unless you ask
for a transcript.

## Usage

```
/octopus:council <the decision or question>
/octopus:council --transcript <the decision or question>
```

**Examples:**

```
/octopus:council should I launch a paid workshop or a free course first?
/octopus:council which of these three positioning angles is strongest?
```

## Instructions

Invoke the `council` skill (`skills/council/SKILL.md`). The skill owns the full
four-phase protocol (frame → convene → anonymous peer review → chairman verdict) —
do not reinterpret it here.
