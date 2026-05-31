---
name: knowledge-briefing
description: (Octopus) Proactive cadence summary over a knowledge root — what changed (since the watermark) + what needs attention; --daily advances, --weekly rolls up. Grounded, cheap-tier narration.
---

# /octopus:knowledge-briefing

## Purpose

Surface "what changed / what needs you today" over a knowledge root without
asking. The change-delta and composition run in the `octopus briefing` core
over `octopus kr` + the sibling engines; the skill narrates grounded on the
cheapest tier. Cadence is hosted by `/schedule` / `/loop`.

## Usage

```
/octopus:knowledge-briefing [--root <id>] [--daily|--weekly] [--since <window>]
```

Invoke the `knowledge-briefing` skill, which wraps `octopus briefing`. See
`skills/knowledge-briefing/SKILL.md` for the sections, grounding, watermark, and
cadence.
