# Spec: /batch skill

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Status** | Implemented |
| **Roadmap** | RM-017 |
| **Research** | [boris-cherny-tips](../research/2026-03-30-boris-cherny-tips.md) (tip 30) |
| **Depends on** | [RM-011 Worktree Isolation](worktree-isolation.md) |

## Problem

Applying a single refactor or codemod across dozens of files/modules sequentially is slow and repetitive. Boris's tip 30 proposes a fan-out pattern: create N git worktrees, run the same prompt in each in parallel, review and merge one-by-one.

## Design

New skill `skills/batch/SKILL.md` delivered to agents that opt in via `skills: [batch]` in `.octopus.yml`.

The skill is a documented pattern, not a shell script. When invoked as `/batch <prompt-file> <targets-pattern>`, the assistant:

1. Validates prerequisites: `worktree: true` in the manifest (RM-011), clean working tree, no overlapping targets.
2. Expands the targets glob and creates one worktree per target under `.worktrees/batch-<n>/`.
3. Dispatches N parallel subagents via `Agent` tool, one per worktree, each running the prompt against its target.
4. Each subagent commits its proposal on a throwaway branch `batch/<parent>-<n>`.
5. Returns a summary table: target → diff stats → branch name.
6. Waits for user approval per worktree (`git merge`) or bulk with `--merge-all`.

Cleanup is documented in the skill file (user runs `git worktree list | … xargs git worktree remove`).

## Failure modes

- **Cross-target dependencies**: two targets depend on the same import; one subagent changes it, the other overwrites on merge. Mitigation: skill instructs the user to verify independence before running.
- **Disk pressure**: N full worktrees consume N × repo size. Skill recommends batches of ~20 for large repos.
- **Prompt ambiguity**: subagents interpret the same prompt differently across targets. Skill recommends piloting on 2-3 targets first.

## Out of scope

- Cross-repo batch (multi-repo fan-out). Octopus boundary is a single repo.
- Automated merge conflict resolution. User reviews each worktree.
- Rollback protocol if a batch half-merges. User uses standard `git` recovery.
