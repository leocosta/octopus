---
name: consigliere-lens
description: (Octopus) Run a knowledge engine against the consigliere workspace and reframe it through the consigliere lens — political risk, per-node playbook, "thinks like you" voice. Read-only.
---

# /octopus:consigliere-lens

## Purpose

Make `hygiene`/`synthesize`/`briefing` read like the consigliere when run over
the private manager-workspace. The engines stay generic; the deterministic
`octopus lens` helper surfaces the grounded material (playbook + political
risk); the consigliere role (opus) frames it. Read-only.

## Usage

```
/octopus:consigliere-lens [--engine hygiene|synthesize|briefing] [--daily|--weekly]
```

Invoke the `consigliere-lens` skill. See `skills/consigliere-lens/SKILL.md` for
the flow, voice, grounding, and write-guard.
