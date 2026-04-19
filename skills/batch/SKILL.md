---
name: batch
description: Fan out a prompt across many targets (files / modules / directories) running each in an isolated git worktree, then merge results back.
---

# Batch — parallel fan-out with worktree isolation

Use this skill when a single intent must be applied to many independent
targets in parallel: codemods, framework upgrades, renaming campaigns,
localization passes, per-module test scaffolding.

The skill runs each target in its own `git worktree` so the main working
tree stays clean and agents can work concurrently without stepping on
each other. Results are reviewed and merged one worktree at a time.

## When to invoke

Good candidates:
- "Apply this refactor to every file under src/api/"
- "Migrate all React class components in components/ to hooks"
- "Add `strict` mode to every tsconfig.json in the monorepo"
- "Translate every README.md under packages/*/"

Bad candidates:
- Changes that share state across targets (one file depends on another)
- Tasks that require sequential decisions (each answer informs the next)
- Work that touches global config / shared infra (lockfiles, CI)

## How it works

1. Caller provides a prompt + a list of targets (paths or patterns).
2. The skill creates one worktree per target under `.worktrees/batch-<n>/`.
3. A subagent runs the prompt against each worktree in parallel.
4. Each subagent commits its changes on a throwaway branch.
5. Results are summarized back to the user with diff stats per target.
6. User approves merges one-by-one (or `--merge-all` after review).

## Pre-requisites

- `worktree: true` in `.octopus.yml` (RM-011) — the manifest flag that
  signals this repository tolerates worktree isolation.
- Targets must be independent (no cross-file dependencies).
- Working tree must be clean before invocation.

## Usage

```
/batch <prompt-file> <targets-pattern>

Examples:
  /batch prompts/migrate-hooks.md 'src/components/*.tsx'
  /batch prompts/add-strict.md   'packages/*/tsconfig.json'
```

After the run, each worktree ends up at `.worktrees/batch-<n>/` with the
proposed changes committed on a branch named `batch/<parent-branch>-<n>`.
Review with:

```
git -C .worktrees/batch-<n> log --oneline
git -C .worktrees/batch-<n> diff HEAD~1
```

Merge back into the parent branch:

```
git merge batch/<parent-branch>-<n>
```

Or discard:

```
git worktree remove .worktrees/batch-<n>
git branch -D batch/<parent-branch>-<n>
```

## Cleanup

After all merges, remove every batch worktree with:

```
git worktree list | awk '/batch-/{print $1}' | xargs -r -n1 git worktree remove
```

## Failure modes

- **Prompt too ambiguous for independent application.** Subagents disagree
  on interpretation across targets. Tighten the prompt with explicit rules
  or run the skill on a smaller pilot first.
- **Targets overlap (same file in multiple globs).** Dedupe before running;
  worktrees will have merge conflicts.
- **Disk pressure.** Worktrees are full working copies. For 100+ targets,
  run in batches of ~20.
