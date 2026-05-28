---
name: audit-config
description: (Octopus) Audit the Octopus configuration surface (rules, skills, hooks, commands, bundles) for model drift, stale dates, phantom skills, and deprecated paths. Severity-tiered report.
---

# /octopus:audit-config

## Purpose

The `audit-config` skill is the quarterly / semestral configuration
freshness check. This slash command drives it explicitly on demand —
the natural cadence is every 3–6 months or after a major
model-family change.

## Usage

```
/octopus:audit-config
```

## Instructions

Invoke the `audit-config` skill (`skills/audit-config/SKILL.md`). The
skill owns the inventory step, the five checks (model-specific
assumptions, stale dates, phantom skills, untouched hooks, deprecated
paths), the severity tiering (`⛔ block` / `⚠ warn` / `ℹ info`), and
the read-only "suggest next step, do not act" rule — do not
reinterpret here.

The audit produces a report only. Fixes are the user's call, applied
as separate commits. Never auto-edit configuration files from inside
this command.
