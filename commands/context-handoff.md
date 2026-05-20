---
name: context-handoff
description: (Octopus) Compact the current conversation into a handoff document in the OS tmp dir, with redacted secrets and a prescriptive suggested-skills section.
---

---
description: (Octopus) Compact the current conversation into a handoff document in the OS tmp dir, with redacted secrets and a prescriptive suggested-skills section.
agent: code
---

# /octopus:context-handoff

## Purpose

The `context-handoff` skill defines the session-handoff discipline;
this slash command drives it explicitly when the user wants to end
the current session and hand the work off to another agent.

## Usage

```
/octopus:context-handoff [optional focus for the next session]
```

## Instructions

Invoke the `context-handoff` skill
(`skills/context-handoff/SKILL.md`). The skill owns the location
rule (OS tmp dir, never the workspace), the redaction pass, and the
prescriptive `Suggested next skills` section — do not reinterpret
here.

Output the absolute path of the handoff file so the user can pass
it to the successor agent.
