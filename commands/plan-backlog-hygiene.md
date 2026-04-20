---
name: plan-backlog-hygiene
description: Scan planning directories + roadmap for orphan plans, concluded-but-not-archived, duplicates, broken links, roadmap orphans, and stale plans.
---

---
description: Scan planning directories + roadmap for orphan plans, concluded-but-not-archived, duplicates, broken links, roadmap orphans, and stale plans.
agent: code
---

# /octopus:plan-backlog-hygiene

## Purpose

Audit the repo's `plans/` directory (or `docs/plans/`,
`docs/superpowers/plans/`) and `docs/roadmap.md` for hygiene issues.
Produces a severity-tiered report (`⚠ Warn` / `ℹ Info`). With `--fix`,
moves concluded plans to `plans/archive/YYYY-MM/`.

## Usage

```
/octopus:plan-backlog-hygiene [--fix] [--write-report] [--plans-dir=<path>] [--stale-days=<n>] [--only=<checks>]
```

## Instructions

Invoke the `plan-backlog-hygiene` skill
(`skills/plan-backlog-hygiene/SKILL.md`). The skill owns the full
workflow: directory discovery, roadmap parsing, six-check execution,
report rendering, and `--fix` moves.

Do not reinterpret the skill here — dispatch to it.
