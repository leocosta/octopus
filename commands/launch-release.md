---
name: launch-release
description: (Octopus) Generate a themed release announcement kit for existing users — landing page, email, Slack, Discord, in-app banner, status page, X thread, WhatsApp, slide deck.
---

# /octopus:launch-release

## Purpose

Turn one or more refs (tags, ranges, RM IDs) into a themed release
kit: canonical landing HTML + channel messages ready to paste. For
existing users — pairs with `launch-feature` (acquisition).

## Usage

```
/octopus:launch-release [<ref>...] [--theme=<name>] [--since=<tag>]
                           [--audience=<level>] [--channels=<list>]
                           [--design-from="<prompt>"] [--dry-run]
```

## Instructions

Invoke the `launch-release` skill
(`skills/launch-release/SKILL.md`). The skill owns the full
workflow: ref resolution, theme resolution (including frontend-design
via `--design-from`), template rendering, and output writing.

Do not reinterpret the skill here — dispatch to it.
