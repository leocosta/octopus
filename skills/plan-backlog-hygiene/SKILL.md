---
name: plan-backlog-hygiene
description: >
  Scan the repo's planning directories and roadmap for hygiene issues —
  orphan plans, plans for already-completed RMs still sitting outside
  `archive/`, duplicates for the same RM, broken internal links,
  roadmap entries without a plan, and stale plans. Default mode is
  read-only; `--fix` applies reversible moves to `plans/archive/`.
---

# Plan-Backlog-Hygiene Protocol

## Overview

This skill keeps the planning surface honest over time. Delivery cycles
accumulate plans, RFCs, specs, and research docs faster than teams
archive them. `plans/` grows to 50+ files and new contributors can't
tell which plan is alive. This skill walks the planning directories and
the roadmap, cross-references the two, and emits findings in the same
severity format used by `money-review` and `cross-stack-contract`.

It does not edit plan content. The only write action is moving
concluded plans into `plans/archive/YYYY-MM/` when invoked with `--fix`.

## Invocation

```
/octopus:plan-backlog-hygiene [--fix] [--write-report] [--plans-dir=<path>] [--stale-days=<n>] [--only=<checks>]
```

**Options:**

- `--fix` — apply reversible actions (move concluded plans to
  `plans/archive/`). Default: read-only report.
- `--write-report` — save report to
  `docs/reviews/YYYY-MM-DD-hygiene.md`.
- `--plans-dir=<path>` — override the plans directory lookup.
- `--stale-days=<n>` — threshold for the stale check. Default: `90`.
- `--only=<list>` — subset of checks:
  `orphan,concluded,duplicate,broken-link,roadmap-orphan,stale`.
