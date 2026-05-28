---
name: triage-issues
description: (Octopus) Run the state-machine triage flow on a single issue — recommend category and state, reproduce bugs, grill, transition.
---

# /octopus:triage-issues

## Purpose

The `triage-issues` skill defines the triage discipline; this slash
command drives it explicitly for a single issue the user names
inline.

## Usage

```
/octopus:triage-issues <issue number or URL>
```

## Instructions

Invoke the `triage-issues` skill
(`skills/triage-issues/SKILL.md`). The skill owns the full
seven-step protocol — do not reinterpret it here.

The mandatory AI disclaimer applies to every comment generated
during this command's execution.
