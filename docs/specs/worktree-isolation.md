# Spec: Worktree Isolation

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Status** | Implemented |
| **Roadmap** | RM-011 |
| **Research** | [boris-cherny-tips](../research/2026-03-30-boris-cherny-tips.md) (tip 30) |

## Problem

Parallel sub-agent work on the same working tree causes race conditions and half-applied changes. Boris's tip 30 proposes `git worktree` isolation so each agent (or batch slice) operates on its own checkout.

## Design

New manifest key `worktree: true`. Parsed in `parse_octopus_yml` into `$OCTOPUS_WORKTREE`, delivered by `deliver_boris_settings` into `.claude/settings.json` as the boolean `"worktree"` key. Claude Code reads the key natively; when absent, behavior is unchanged.

The key is a signal — it tells CC and downstream skills (notably `/batch`) that this repo tolerates `.worktrees/` creation. No worktrees are created by `setup.sh` itself.

## Consumers

- `/batch` skill (RM-017) requires `worktree: true` before fanning out.
- Future: custom slash commands that want parallel execution can check the setting.

## Out of scope

- Cleanup of stale worktrees (user responsibility; `git worktree prune`).
- Cross-repo worktrees.
