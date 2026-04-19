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

## Hygiene Checks

Each plan file is evaluated against the six checks below. Findings are
grouped by severity. Families are skippable via `--only`.

### H1 orphan — plan without any identifier

A plan body (and frontmatter) contains no `RM-\d+`, no PR reference,
no issue reference, and no link into `docs/specs/`, `docs/rfcs/`, or
`docs/research/`.

This is usually a draft that was never wired into the lifecycle.

Severity: ℹ Info.

### H2 concluded — plan for a completed RM not archived

The plan references `RM-NNN`; the roadmap marks that RM as concluded
(`completed`, `done`, `shipped`); and the plan file path does NOT
start with `plans/archive/` (or `<plansDir>/archive/`).

Severity: ⚠ Warn.

With `--fix`: move the file to
`<plansDir>/archive/YYYY-MM/<filename>` where `YYYY-MM` is derived
from the RM's completion date (fallback: current month). Use
`git mv` so history is preserved.

### H3 duplicate — two or more plans for the same RM

Two or more plan files reference the same `RM-NNN` in body or
frontmatter. The skill lists all candidates and flags the set.

Severity: ⚠ Warn. No auto-fix (team judgment call).

### H4 broken-link — plan cites a missing file

A plan contains a markdown link whose target path starts with one of
the internal prefixes (`docs/specs/`, `docs/rfcs/`, `docs/research/`,
`docs/adrs/`, `plans/`) but the target file does not exist.

Severity: ⚠ Warn. No auto-fix.

### H5 roadmap-orphan — RM without a plan

The roadmap has an entry `RM-NNN` whose status is `in progress`,
`wip`, `proposed`, or `blocked`, and no plan file in the plans
directory references that ID.

Not all RMs need a plan (trivial work may ship without one), so this
is informational.

Severity: ℹ Info.

### H6 stale — plan unchanged for too long (continued)

<!-- keep H6 searchable -->



A plan's most recent commit is older than `--stale-days` (default 90)
AND the plan does not link an already-concluded RM. When the file has
no git history (bulk-imported), fall back to filesystem mtime.

Severity: ℹ Info.

## Output

Same three-heading severity format used by `money-review` and
`cross-stack-contract`. v1 does not emit any 🚫 Block findings, so the
block heading is always empty — it is kept for format compatibility.

```markdown
## 🚫 Block (0)
- (none)

## ⚠ Warn (N)
- H2 **concluded**: `plans/split-asaas-fase2.md` references RM-013
  (completed); move to `plans/archive/2026-04/` with `--fix`.
- H4 **broken-link**: `plans/abstract-greeting-hamster.md:9` cites
  `docs/specs/enrollment.md` which does not exist.

## ℹ Info (N)
- H1 **orphan**: `plans/clever-honking-haven.md` references no RM,
  PR, or spec.
- H5 **roadmap-orphan**: RM-014 (in progress) has no plan file.
- H6 **stale**: `plans/controle-de-acesso.md` unchanged for 180 days.

plan-backlog-hygiene: 0 block, 2 warn, 3 info (scanned 54 plan files)
```

With `--write-report`: content is persisted to
`docs/reviews/YYYY-MM-DD-hygiene.md` with a frontmatter block:

```yaml
---
plans_dir: plans/
roadmap: docs/roadmap.md
generated_by: octopus:plan-backlog-hygiene
generated_at: 2026-04-19
summary: "0 block, 2 warn, 3 info"
scanned_files: 54
---
```

## Fix Mode

`--fix` applies reversible filesystem moves for a single check:

- **H2 concluded** — each matched plan is moved to
  `<plansDir>/archive/YYYY-MM/<filename>` using `git mv` so commit
  history is preserved. `YYYY-MM` comes from the RM's completion date
  when parseable in the roadmap; otherwise the current month.

Other checks (H1, H3, H4, H5, H6) are never auto-fixed — each needs
human judgment.

**Safety rules:**

- `--fix` requires a clean working tree. Abort otherwise with the hint
  `commit or stash local changes before running --fix`.
- After applying moves, print a summary listing each move, then remind
  the user the change is a staged `git mv` — commit or `git restore
  --staged` to undo.
- `--fix` and `--write-report` may be combined; the report lists the
  applied moves under a "Fixes applied" section.

## Errors

- **Plans directory not found** → abort with guidance to set
  `plansDir:` or create `plans/`.
- **Roadmap missing** → print a warning, skip H2/H5, continue.
- **`--fix` with a dirty working tree** → abort.
- **Unrecognized `--only` check** → abort, list valid check IDs.
- **Git unavailable** → fall back to mtime for H6 staleness; warn once.

## Composition

This skill scans repo state (not a diff) and runs independently of
`money-review` and `cross-stack-contract`. The output format matches so
a monthly "hygiene digest" PR can concatenate all three reports in a
single comment.
