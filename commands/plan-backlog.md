---
name: plan-backlog
description: (Octopus) Scan planning directories + roadmap for orphan plans, concluded-but-not-archived, duplicates, broken links, roadmap orphans, and stale plans.
---

# /octopus:plan-backlog

## Purpose

Audit the repo's `plans/` directory (or `docs/plans/`) and
`docs/roadmap.md` for hygiene issues.
Produces a severity-tiered report (`⚠ Warn` / `ℹ Info`). With `--fix`,
moves concluded plans to `plans/archive/YYYY-MM/`.

## Usage

```
/octopus:plan-backlog [--fix] [--write-report] [--plans-dir=<path>] [--stale-days=<n>] [--only=<checks>]
```

## Instructions

Invoke the `plan-backlog` skill
(`skills/plan-backlog/SKILL.md`). The skill owns the full
workflow: directory discovery, roadmap parsing, six-check execution,
report rendering, and `--fix` moves.

Do not reinterpret the skill here — dispatch to it.
