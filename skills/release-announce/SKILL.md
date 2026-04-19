---
name: release-announce
description: >
  Generate a themed release announcement for existing users from one
  or more refs (tags, tag ranges, RM IDs). Produces canonical
  artifacts (landing HTML, plain notes, theme snapshot) and paste-ready
  channel messages (email, Slack, Discord, in-app banner, status page,
  X/Twitter, WhatsApp, slide deck). Supports preset themes and on-demand
  custom theme synthesis via frontend-design.
---

# Release-Announce Protocol

## Overview

This skill announces what changed in a release to existing users.
Distinct from `feature-to-market`, which handles acquisition / external
audiences. Inputs are versions or RMs; outputs are a themed landing
page + channel-specific paste-ready messages.

The default path is deterministic: refs → highlights → preset theme →
templates → output. When `--design-from="<prompt>"` is passed, the
skill invokes `frontend-design` to synthesize a new theme YAML, then
continues with the deterministic render.

## Invocation

```
/octopus:release-announce [<ref>...] [--theme=<name>] [--since=<tag>]
                           [--audience=<level>] [--channels=<list>]
                           [--design-from="<prompt>"] [--dry-run]
```

**Arguments:**

- `<ref>...` (zero or more) — tag (`v1.7.0`), tag range
  (`v1.5.0..v1.7.0`), or RM ID (`RM-008`). Union semantics.
  Default when none: `--since=<last-release-tag>..HEAD`.

**Options:**

- `--theme=<name>` — one of the installed themes. Default from
  `.octopus.yml theme:`, else `classic`.
- `--since=<tag>` — shortcut for `<tag>..HEAD` when no positional
  refs are given.
- `--audience=<user|developer|executive>` — tunes voice and detail.
  Default: `user`.
- `--channels=<list>` — subset of
  `email,slack,discord,in-app-banner,status-page,x-announcement,whatsapp,slides`.
  Default: `email,slack,in-app-banner`. `all` generates every channel.
  `none` skips `channels/` and writes only canonical artifacts.
- `--design-from="<prompt>"` — synthesize a custom theme via
  `frontend-design`. Overrides `--theme` with a warning when both are
  passed.
- `--dry-run` — print the plan and exit 0 without writing files.
