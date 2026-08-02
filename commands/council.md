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
/octopus:council --pre-mortem <the plan or launch>
```

- `--transcript` — also save a `council-transcript-<slug>.md` in the working directory.
- `--pre-mortem` — treat the plan as **already failed** and have the council explain
  why. Same five lenses, same anonymous review; the verdict becomes ranked failure
  modes, each with a mitigation and a tripwire. Use it when the call is made and you
  want the blind spots before spending the money.

**Examples:**

```
/octopus:council should I launch a paid workshop or a free course first?
/octopus:council which of these three positioning angles is strongest?
/octopus:council --pre-mortem we ship the new checkout in six weeks
```

## Instructions

Invoke the `council` skill (`skills/council/SKILL.md`). The skill owns the full
four-phase protocol (frame → convene → anonymous peer review → chairman verdict) —
do not reinterpret it here.
