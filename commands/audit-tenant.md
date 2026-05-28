---
name: audit-tenant
description: (Octopus) Pre-merge audit of multi-tenant data-scope enforcement — query filters, new entity configs, raw SQL, controller ownership, admin endpoints.
---

# /octopus:audit-tenant

## Purpose

Scan the current branch (or a provided ref) for missing tenant-scope
enforcement before merge. Produces a severity-tiered report
(`🚫 Block` / `⚠ Warn` / `ℹ Info`) with confidence labels, covering
six checks critical to multi-tenant SaaS codebases.

## Usage

```
/octopus:audit-tenant [ref] [--base=main] [--only=<checks>] [--write-report]
```

## Instructions

Invoke the `audit-tenant` skill
(`skills/audit-tenant/SKILL.md`). The skill owns the full
workflow: config resolution, file discovery, six-check execution, and
report rendering.

Do not reinterpret the skill here — dispatch to it.
