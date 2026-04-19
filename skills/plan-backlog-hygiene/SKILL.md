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

## Plans Directory Discovery

Resolve the plans directory in this order:

1. `.octopus.yml` top-level field `plansDir:` (string path). When
   present, it wins.
2. Autodetection — first existing directory among: `plans/`,
   `docs/plans/`, `docs/superpowers/plans/`. If more than one exists,
   pick the directory with the most `*.md` files.
3. If none of the above exist, abort with the message
   "no plans directory found — set `plansDir:` in `.octopus.yml`
   or create `plans/`".

The roadmap lookup is always `docs/roadmap.md`. If missing, checks
`concluded` and `roadmap-orphan` are skipped with a note; the other
checks continue.

Reference-pattern overrides live at:

- `docs/plan-backlog-hygiene/patterns.md` (canonical)
- `docs/PLAN_BACKLOG_HYGIENE_PATTERNS.md` (uppercase compat)
- `skills/plan-backlog-hygiene/templates/patterns.md` (embedded default)

Overrides append to the defaults.
