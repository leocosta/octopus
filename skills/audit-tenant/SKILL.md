---
name: audit-tenant
description: >
  Pre-merge audit of multi-tenant data-scope enforcement. Given a branch
  or PR, detects queries that bypass tenant filters, DbContexts missing
  HasQueryFilter for new entities, raw SQL without tenant restriction,
  controllers that accept ids from routes without ownership checks,
  joins to unfiltered tables, and cross-tenant admin endpoints without
  explicit markers. Produces a severity-tiered report with confidence
  labels.
triggers:
  paths: []
  keywords: ["tenant", "org", "workspace", "multi-tenant", "organization"]
  tools: []
pre_pass:
  file_patterns: "tenant|org|workspace|organization|scope"
  line_patterns: "tenantId|orgId|workspaceId|TenantId|OrgId"
---

# Tenant-Scope-Audit Protocol

## Overview

This skill protects multi-tenant SaaS codebases from the systemic bug
where a query without a tenant filter leaks data across tenants. EF
Core offers `HasQueryFilter` for this, but the contract is easy to
break: `IgnoreQueryFilters()`, `FromSqlRaw`, a new entity added to the
DbContext without configuration, a controller that finds by `id`
without verifying ownership.

The skill composes with `audit-security`, `audit-money`, and
`review-contracts`. All four emit the same severity format so
their reports concatenate into a single PR comment.

## Invocation

```
/octopus:audit-tenant [ref] [--base=main] [--only=<checks>] [--write-report]
```

Flags `ref`, `--base`, `--only`, `--write-report` follow the shared
convention — see [`_shared/audit-output-format.md`](../_shared/audit-output-format.md).

Valid `--only` checks:
`query-without-filter,dbcontext-missing-filter,raw-sql-no-filter,id-from-route-no-ownership,join-to-unfiltered-table,cross-tenant-admin-endpoint`.
Report prefix: `tenant`.

## Tenant-Scope Config

Resolve configuration in this order:

1. `.octopus.yml` top-level `tenantScope:` map:
   ```yaml
   tenantScope:
     field: TenantId            # tenant FK column name
     filter: AppQueryFilter     # helper/query filter used by the project
     context: AppDbContext      # primary DbContext class name
     entities:                  # (optional) explicit tenant-scoped entity list
       - Student
       - Class
       - Subscription
   ```
2. Defaults when the key is absent:
   - `field = TenantId`
   - `filter = AppQueryFilter`
   - `context = AppDbContext`
   - `entities` unset → T2 flags every new DbSet added to the DbContext.

When the manifest has a malformed `tenantScope:` section, warn, fall
back to defaults, and continue.

## File Discovery

Follow the Pre-Pass protocol in `skills/_shared/audit-pre-pass.md`.
Use this skill's `pre_pass.file_patterns` and `pre_pass.line_patterns` from the frontmatter.
Then follow the Cache protocol in `skills/_shared/audit-cache.md` before proceeding to inspection checks.

## Inspection Checks

Each check produces zero or more findings. Every finding is labeled
with a `confidence` level (`high` / `medium` / `low`) so reviewers can
triage heuristic matches. Checks are skippable via `--only`.

### T1 query-without-filter — bypassing the tenant filter

Scan the diff for `IgnoreQueryFilters()` calls. For each occurrence:

- Read the immediately preceding line.
- If it matches `// tenant-override: <reason>` with non-empty reason,
  suppress the finding.
- Otherwise, emit **🚫 Block**.

Example message:
> T1 **query-without-filter** (high): `IgnoreQueryFilters()` at
> `api/src/Students/StudentQueries.cs:42` has no tenant-override
> justification.

### T2 dbcontext-missing-filter — new entity without HasQueryFilter

Scan for new `DbSet<X>` properties added to the file matching the
configured `context` name (default `AppDbContext`). For each new entity
`X`:

- Search the same file's `OnModelCreating` additions in the diff for
  `modelBuilder.Entity<X>().HasQueryFilter(...)` OR an `IEntityTypeConfiguration<X>`
  reference.
- If `tenantScope.entities:` is configured, skip entities NOT in the
  list (treated as global).
- Emit **🚫 Block** when the filter is missing.

### T3 raw-sql-no-filter — raw SQL without tenant restriction

Scan for raw-SQL helpers (see `patterns.md`): `FromSqlRaw`,
`FromSqlInterpolated`, `ExecuteSqlRaw`, `ExecuteSqlInterpolated`,
`Database.SqlQuery`.

For each call, extract the SQL string literal. If the string does not
contain any recognized tenant-field token (case-insensitive), emit
**🚫 Block**.

### T4 id-from-route-no-ownership — controller `id` lookup without check

Scan controller methods added/modified in the diff. A finding triggers
when all of these hold:

1. The method has a parameter `id` or `{id}` bound from the route
   (ASP.NET route templates) or query.
2. The body calls `.FindAsync(id)`, `.Find(id)`,
   `.FirstOrDefault(x => x.Id == id)`, `.SingleOrDefault(...)` on
   a `DbSet<X>` where `X` is tenant-scoped (either listed in
   `tenantScope.entities:` or detected as having `HasQueryFilter`).
3. Neither the body nor the method attributes call one of the ownership
   helper names from `patterns.md`.

Severity: ⚠ Warn (defense-in-depth — EF query filter, if correctly
configured, already enforces scope, but a dropped filter in the future
would expose this path).

### T5 join-to-unfiltered-table — join to a global table without restriction

Scan LINQ `Join(...)` / `from ... in ... join ... in ... on ...`
expressions in tenant-relevant files.

For each join:

- Identify the right-side `DbSet<Y>`.
- If `Y` is NOT in the tenant-scoped entity set (either the
  `tenantScope.entities:` list or entities with `HasQueryFilter`), AND
  the join predicate does not constrain by the configured `field`,
  emit **⚠ Warn**.

### T6 cross-tenant-admin-endpoint — admin endpoint touching tenant data

Scan controller methods that carry `[AllowAnonymous]` or
`[Authorize(Roles = "Admin")]` / `[Authorize(Roles = "SuperAdmin")]`.

For each such method:

- If the method body accesses a tenant-scoped `DbSet` AND no preceding
  line comment `// across-tenants: <reason>` is present, emit
  **⚠ Warn**.
- The comment must carry a non-empty reason; an empty marker is
  rejected.

## Output

Severity headings, confidence labels, and `--write-report`
frontmatter follow the shared format — see
[`_shared/audit-output-format.md`](../_shared/audit-output-format.md).
Skill-specific notes:

- Finding ID prefix: `T1`–`T6`.
- Trailer appends the effective config:
  `audit-tenant: N block, N warn, N info (config: <field> via <filter> / <context>)`.
- Report path: `docs/reviews/YYYY-MM-DD-tenant-<slug>.md`.
- Frontmatter adds a `config:` block mirroring the active
  `field` / `filter` / `context`.

## Errors

Shared errors (not in git repo, base branch missing, no relevant
files, malformed override, unrecognized `--only`) behave per the
shared convention. Skill-specific wording:

- **No tenant-relevant files in diff** →
  `no tenant-scope changes detected`.
- **Malformed `tenantScope:` in `.octopus.yml`** → warn, fall back
  to defaults, continue.

## Composition

Composes with `audit-security`, `audit-money`, and
`review-contracts`. In multi-tenant code, reviewers should treat
🚫 Block findings as merge blockers — each one is a potential
data-leak path.
