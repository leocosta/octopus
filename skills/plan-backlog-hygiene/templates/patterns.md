# Plan-Backlog-Hygiene Patterns (default)

> Embedded default. Override at `docs/plan-backlog-hygiene/patterns.md`.
> Overrides append; they do not replace the defaults.

## Roadmap identifiers

Match any of these forms inside a plan body or frontmatter:

- `\bRM-\d+\b` — canonical roadmap ID.
- `\bROADMAP-\d+\b` — alternate convention.
- Issue references: `#\d+`, `GH-\d+`, `gh-\d+`.
- PR references: `PR-\d+`, `\bpull/\d+\b`.

## Internal links to spec / research

Match markdown links whose target starts with:

- `docs/specs/`
- `docs/rfcs/`
- `docs/research/`
- `docs/adrs/` or `docs/adr/`
- `plans/` (self-references)

For each such link, the skill verifies the target file exists.

## Roadmap status parsing

Inside `docs/roadmap.md`, each `### RM-\d+` section is expected to have
a `- **Status:** <value>` line. Recognized statuses:

- `completed`, `done`, `shipped` → considered concluded
- `in progress`, `in_progress`, `wip`, `doing` → active
- `proposed`, `backlog`, `planned` → pending
- `blocked`, `on hold` → stalled (treated as active for H5)

Missing or unknown status → treated as active.

## Archive convention

Concluded plans are moved to `plans/archive/YYYY-MM/<filename>` when
`--fix` is used. If the plans directory is `docs/plans/`, the archive
is `docs/plans/archive/YYYY-MM/`. The `YYYY-MM` segment uses the
concluded RM's completion date when available; otherwise the current
month.
