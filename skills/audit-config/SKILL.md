---
name: audit-config
description: >
  Pre-merge audit of the Octopus configuration surface — rules/, skills/,
  hooks/, commands/, bundles/. Inspects for model-specific assumptions
  (Opus 3, Claude 3.5), stale date references without follow-up, skills
  with no triggers and no description-driven hints, hooks untouched since
  the last model-family change, and commands referencing deprecated paths.
  Produces a severity-tiered report (block / warn / info) in the same
  shape as audit-all. Active by default on the quality bundle; pairs
  with plan-backlog (plan hygiene) and audit-all (code audits) to round
  out the periodic-review surface.
triggers:
  paths: ["rules/**/*.md", "skills/**/SKILL.md", "hooks/**/*.sh", "commands/**/*.md", "bundles/**/*.yml"]
  keywords: ["audit config", "config audit", "stale rules", "model drift"]
---

# Configuration Freshness Audit

## Overview

Octopus already audits the **code** (`audit-all` composes
`audit-security`, `audit-money`, `audit-tenant`, `audit-contracts`)
and the **plans** (`plan-backlog`). What was missing until now is an
audit of the **configuration surface itself** — the rules, skills,
hooks, commands, and bundles that shape how the agents behave.

Configuration ages differently from code. A rule written for an older
model can silently constrain a newer one. A skill without `triggers:`
becomes a phantom — present in the repo but never engaged. A hook that
predates a model-family change may enforce a discipline that no longer
applies. `audit-config` catches that drift early.

The skill is **read-only**. It produces a report; it never edits the
configuration. Fixes are the user's call, applied as separate commits.

## When to Engage

Engage when:

- Quarterly / semestral configuration review (the article's 3–6 month
  cadence)
- After a major model-family change (Sonnet → Opus, Opus 4.6 → 4.7) —
  rules calibrated for the prior family may now under- or over-shoot
- Performance plateaus after a model upgrade — the rules may be
  constraining the new model's capabilities
- Before opening a new cluster of work — start clean
- Triggered automatically on edits to `rules/`, `skills/`, `hooks/`,
  `commands/`, or `bundles/` (see `triggers:` frontmatter)

Do **not** engage when:

- The repo is brand-new (`octopus update` was run < 90 days ago) —
  there is nothing to age
- The user is in the middle of an active feature implementation —
  the audit produces noise that distracts from the immediate task

## Protocol

### Step 1 — Inventory the configuration surface

Walk these directories and list every file:

- `rules/**/*.md`
- `skills/**/SKILL.md` (and any `REFERENCE.md`)
- `hooks/**/*.sh` and `hooks/hooks.json`
- `commands/**/*.md`
- `bundles/**/*.yml`

Capture for each: path, last-modified date (via `git log -1 --format=%cd
-- <path>`), line count.

### Step 2 — Run the five checks

For each file, run the applicable checks. Severity guidance below.

**Check 1 — Model-specific assumptions** (severity: ⚠ warn)

Grep for: `Opus 3`, `Claude 3.5`, `Claude 3 Opus`, `gpt-4`, `Sonnet 3`,
explicit version pins to old families. Flag with the file path, the
line, and the model named.

**Check 2 — Stale date references** (severity: ℹ info, ⚠ warn after 9
months)

Grep for date patterns (`YYYY-MM`, `Q[1-4] 20\d\d`). For each match,
compute age. Info under 9 months, warn at 9+ months without a
follow-up comment naming a successor date.

**Check 3 — Skills without triggers and without invocation hints**
(severity: ⚠ warn)

For each `skills/<name>/SKILL.md`, parse the frontmatter. If there is
no `triggers:` field **and** the description does not contain any of
the routing cues (`pairs with`, `active by default`, `family`,
`triggers on`, `Use when`, `Active on`), flag — the skill is a phantom.

**Check 4 — Hooks untouched since a model-family change** (severity:
ℹ info)

For each `hooks/**/*.sh`, compare last-modified date to the date of
the most recent `claude-*` model-family entry in any tracked
configuration (heuristic: any file mentioning a new model name). If
the hook predates that date by more than 6 months, flag.

This check is heuristic — false positives are expected; treat as a
prompt to review, not a defect.

**Check 5 — Commands referencing deprecated paths** (severity: ⛔ block
if a `.gitignore` entry matches, else ⚠ warn)

For each `commands/**/*.md`, grep for paths referenced. For each
path, check whether it (a) still exists on disk, (b) is gitignored.
If it does not exist, warn. If it is gitignored, block — the command
references a path the user explicitly removed.

This check catches problems like the `docs/superpowers/plans/`
cleanup pattern that surfaced in the v1.49.x series.

### Step 3 — Produce the report

Output one section per severity. Within each, group by check, then
list affected files with the specific finding:

```
## ⛔ Block

### Commands referencing deprecated paths

- `commands/foo.md:42` — references `docs/old-thing/` which is gitignored

## ⚠ Warn

### Model-specific assumptions

- `rules/typescript/style.md:18` — names "Opus 3" as default model

### Skills without triggers or invocation hints

- `skills/example/SKILL.md` — no `triggers:` and no routing cue in
  description (capability statement only)

## ℹ Info

### Hooks untouched since the last model-family change

- `hooks/pre-tool-use/legacy.sh` — last modified 2025-09-12, before
  Claude 4.7 entry on 2026-04-15
```

### Step 4 — Suggest the next step, do not act

End the report with a one-line suggestion per finding category — for
example:

```
Next steps:
- ⛔ commands → update or remove the referenced paths in the affected
  commands
- ⚠ rules → either update the model name or remove the version pin
- ℹ hooks → manual review; if still relevant, touch the file with a
  comment dated today to clear the heuristic
```

Never auto-fix. Configuration is load-bearing; the user decides.

## Anti-Patterns

- Auto-fixing any finding — `audit-config` is read-only
- Treating Check 4 (untouched hooks) as a defect — it is a heuristic
  prompt for review, not a violation
- Producing the report without severities — a flat list is unusable
- Running on every edit — the `triggers:` field handles selective
  engagement; do not invoke globally
- Flagging dates that have a "successor" comment naming a later
  follow-up date — those are intentional checkpoints, not staleness

## Integration with Other Skills

- **`audit-all`** — sibling composer. `audit-config` is **not** part
  of `audit-all` by default because its cadence is quarterly, not
  per-merge. Compose only when the user explicitly opts in
- **`plan-backlog`** — adjacent — both are periodic hygiene audits;
  `plan-backlog` covers `docs/plans/` and `docs/roadmap.md`,
  `audit-config` covers the configuration surface
- **`compress-skill`** — sometimes the right follow-up to a
  warn-level "skill description too vague" finding
- **`continuous-learning`** — when a finding recurs across audits,
  promote the underlying pattern to a tracked rule
