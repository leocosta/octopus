---
name: launch-release
description: Generate a themed release announcement kit for existing users — landing page, email, Slack, Discord, in-app banner, status page, X thread, WhatsApp, slide deck.
---

---
description: Generate a themed release announcement kit for existing users — landing page, email, Slack, Discord, in-app banner, status page, X thread, WhatsApp, slide deck.
agent: code
---

# /octopus:release-announce

## Purpose

Turn one or more refs (tags, ranges, RM IDs) into a themed release
kit: canonical landing HTML + channel messages ready to paste. For
existing users — pairs with `feature-to-market` (acquisition).

## Usage

```
/octopus:release-announce [<ref>...] [--theme=<name>] [--since=<tag>]
                           [--audience=<level>] [--channels=<list>]
                           [--design-from="<prompt>"] [--dry-run]
```

## Instructions

Invoke the `release-announce` skill
(`skills/release-announce/SKILL.md`). The skill owns the full
workflow: ref resolution, theme resolution (including frontend-design
via `--design-from`), template rendering, and output writing.

Do not reinterpret the skill here — dispatch to it.
