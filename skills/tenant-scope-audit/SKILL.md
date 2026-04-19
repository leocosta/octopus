---
name: tenant-scope-audit
description: >
  Pre-merge audit of multi-tenant data-scope enforcement. Given a branch
  or PR, detects queries that bypass tenant filters, DbContexts missing
  HasQueryFilter for new entities, raw SQL without tenant restriction,
  controllers that accept ids from routes without ownership checks,
  joins to unfiltered tables, and cross-tenant admin endpoints without
  explicit markers. Produces a severity-tiered report with confidence
  labels.
---

# Tenant-Scope-Audit Protocol

## Overview

This skill protects multi-tenant SaaS codebases from the systemic bug
where a query without a tenant filter leaks data across tenants. EF
Core offers `HasQueryFilter` for this, but the contract is easy to
break: `IgnoreQueryFilters()`, `FromSqlRaw`, a new entity added to the
DbContext without configuration, a controller that finds by `id`
without verifying ownership.

The skill composes with `security-scan`, `money-review`, and
`cross-stack-contract`. All four emit the same severity format so
their reports concatenate into a single PR comment.

## Invocation

```
/octopus:tenant-scope-audit [ref] [--base=main] [--only=<checks>] [--write-report]
```

**Arguments / options:**

- `ref` (optional) — PR (`#123`/URL), branch name, or commit SHA.
  Default: current HEAD vs its upstream.
- `--base=<branch>` — base for the diff. Default: `main`.
- `--only=<list>` — comma-separated subset of checks:
  `query-without-filter,dbcontext-missing-filter,raw-sql-no-filter,id-from-route-no-ownership,join-to-unfiltered-table,cross-tenant-admin-endpoint`.
- `--write-report` — also save
  `docs/reviews/YYYY-MM-DD-tenant-<slug>.md`.
