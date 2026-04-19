# Plan-Backlog-Hygiene

Keeps the planning surface honest over time. Scans `plans/` (or
`docs/plans/`, `docs/superpowers/plans/`) and `docs/roadmap.md` for
orphan plans, plans for already-completed RMs still sitting outside
`archive/`, duplicates for the same RM, broken internal links,
roadmap entries without a plan, and stale plans.

## When to use

Run monthly on any repo with >20 plans, or any time the backlog feels
out of date. Works great as a recurring scheduled task.

## Enable

```yaml
# .octopus.yml
skills:
  - plan-backlog-hygiene

# Optional: override the plans directory if non-standard.
plansDir: docs/plans
```

Run `octopus setup`.

## Use

```
/octopus:plan-backlog-hygiene                     # read-only scan
/octopus:plan-backlog-hygiene --fix               # move concluded plans
/octopus:plan-backlog-hygiene --stale-days=180
/octopus:plan-backlog-hygiene --only=concluded,broken-link
/octopus:plan-backlog-hygiene --write-report
```

## Hygiene checks

- **H1 orphan** — a plan that references no RM, PR, issue, or spec
  (ℹ Info).
- **H2 concluded** — a plan for an RM marked `completed` on the
  roadmap, but the plan file is still outside `plans/archive/`
  (⚠ Warn; auto-fixable with `--fix`).
- **H3 duplicate** — two or more plans cover the same RM (⚠ Warn).
- **H4 broken-link** — a plan cites `docs/specs/...`, `docs/rfcs/...`,
  or another internal path that no longer exists (⚠ Warn).
- **H5 roadmap-orphan** — the roadmap has `RM-NNN` in progress / proposed
  with no matching plan file (ℹ Info).
- **H6 stale** — a plan unchanged for more than `--stale-days`
  (default 90) and not tied to a concluded RM (ℹ Info).

## `--fix` semantics

Only H2 is auto-fixed. The skill moves each matched plan to
`<plansDir>/archive/YYYY-MM/<filename>` using `git mv`, preserving
history. The move is staged in git — commit or `git restore --staged`
to undo.

`--fix` requires a clean working tree.

## Overrides

- `docs/plan-backlog-hygiene/patterns.md` — append repo-specific
  regex for RM/PR/spec-link detection.
- `.octopus.yml` `plansDir:` — override autodetection.

## Scheduled usage

Pair with Octopus's `schedule` skill to run monthly:

```
/schedule "0 9 1 * *" /octopus:plan-backlog-hygiene --write-report
```

## Review before merge

The report is guidance. H1/H5/H6 are always informational — decide
per item whether it's worth acting on. H2/H3/H4 are warnings that
usually warrant action.
