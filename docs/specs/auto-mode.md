# Spec: Auto Mode (permissionMode)

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Status** | Implemented |
| **Roadmap** | RM-012 |
| **Research** | [boris-cherny-tips](../research/2026-03-30-boris-cherny-tips.md) (tip 42) |

## Problem

Claude Code prompts for permission on every sensitive tool call by default. Boris's tip 42 documents a built-in AI classifier that auto-approves safe calls when `permissionMode: "auto"` is set. Octopus users had to hand-edit `.claude/settings.json` to opt in.

## Design

New manifest key `permissionMode: <mode>` with values:

- `default` — prompt for everything (unchanged behavior)
- `plan` — require plan mode before mutations
- `auto` — AI classifier auto-approves safe calls
- `acceptEdits` — auto-approves file edits only
- `bypassPermissions` — opt out entirely (not recommended)

Parsed into `$OCTOPUS_PERMISSION_MODE`, delivered via `deliver_boris_settings` into `.claude/settings.json` as `"permissionMode"`. Empty default means Octopus does not touch the key and CC applies its own default.

## Security note

Setting `permissionMode: auto` trusts CC's classifier. Combine with `sandbox: true` (RM-014) for defense-in-depth.

## Out of scope

- Custom permission classifiers (CC feature, not an Octopus surface).
- Per-agent permission modes — only Claude supports this key today.
