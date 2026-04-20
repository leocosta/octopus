---
name: audit-all
description: Run all quality-audit skills in parallel against one ref — consolidated severity report with a cross-audit hotspots table.
---

---
description: Run all quality-audit skills in parallel against one ref — consolidated severity report with a cross-audit hotspots table.
agent: code
---

# /octopus:audit-all

## Purpose

Run `security-scan`, `money-review`, `tenant-scope-audit`, and
`cross-stack-contract` in parallel against a single ref with
shared file discovery. Output is a consolidated severity report
with cross-audit hotspots.

## Usage

```
/octopus:audit-all [ref] [--base=main] [--only=<audits>] [--write-report]
```

## Instructions

Invoke the `audit-all` skill (`skills/audit-all/SKILL.md`). The
skill owns the full workflow: shared discovery, parallel dispatch,
and consolidated rendering.

Do not reinterpret the skill here — dispatch to it.
