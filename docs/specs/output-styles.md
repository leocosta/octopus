# Spec: Output Styles

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Status** | Implemented |
| **Roadmap** | RM-015 |
| **Research** | [boris-cherny-tips](../research/2026-03-30-boris-cherny-tips.md) (output-styles section) |

## Problem

Default Claude Code output style varies by user preference. Teams that standardize on a specific tone (concise PR bodies, structured commit messages, verbose explanations for juniors) had to ask every developer to set it individually.

## Design

New manifest key `outputStyle: <style>`. Accepted values mirror CC's built-ins:

- `concise` — minimal prose, direct answers
- `verbose` — full reasoning, longer replies
- `structured` — headed sections, bullet-heavy
- `explanatory` — tutorial-style, walkthrough tone

Parsed into `$OCTOPUS_OUTPUT_STYLE`, delivered via `deliver_boris_settings` into `.claude/settings.json` as `"outputStyle"`. When unset, Octopus does not touch the key.

## Out of scope

- Custom output style authoring (CC feature, not a manifest surface).
- Per-role output styles — the key is global to the repo.
