# Tenant-Scope-Audit

Pre-merge audit for multi-tenant data-scope enforcement. Catches the
class of bugs generic review misses: a query without a tenant filter,
a new entity added to the DbContext without `HasQueryFilter`, raw SQL
that forgets to restrict by tenant, a controller that finds by `id`
without verifying ownership, a join to a global table that leaks rows,
or an admin endpoint accessing tenant data without an explicit marker.

One bug in this layer means one tenant sees another tenant's data.

## When to use

Before merging any PR that touches a `DbContext`, a controller, a
query helper, or anywhere the `TenantId` discipline applies. Runs well
alongside `audit-security`, `audit-money`, and `review-contracts`.

## Enable

```yaml
# .octopus.yml
skills:
  - audit-tenant

# Optional: configure the tenant field, filter helper, and DbContext.
# Defaults are TenantId / AppQueryFilter / AppDbContext.
tenantScope:
  field: TenantId
  filter: AppQueryFilter
  context: AppDbContext
  entities:            # (optional) explicit tenant-scoped entity list
    - Student
    - Class
    - Subscription
```

Run `octopus setup`.

## Use

```
/octopus:audit-tenant                       # current branch vs main
/octopus:audit-tenant #123                  # a PR
/octopus:audit-tenant --base=main --only=query-without-filter,dbcontext-missing-filter
/octopus:audit-tenant --write-report
```

## Inspection checks

- **T1 query-without-filter** — `IgnoreQueryFilters()` without a
  preceding `// tenant-override: <reason>` comment (🚫 Block).
- **T2 dbcontext-missing-filter** — new `DbSet<X>` added to the
  configured DbContext without `HasQueryFilter` (🚫 Block).
- **T3 raw-sql-no-filter** — `FromSqlRaw` / `ExecuteSqlRaw` /
  `Database.SqlQuery` whose SQL literal doesn't mention the tenant
  field (🚫 Block).
- **T4 id-from-route-no-ownership** — controller action accepts `id`
  from route/query and calls `.FindAsync(id)` / `.FirstOrDefault(...)`
  on a tenant-scoped DbSet without a known ownership helper (⚠ Warn).
- **T5 join-to-unfiltered-table** — LINQ join to a global table
  without restricting by tenant (⚠ Warn).
- **T6 cross-tenant-admin-endpoint** — `[AllowAnonymous]` or
  `[Authorize(Roles = "Admin")]` method touches tenant-scoped data
  without a `// across-tenants: <reason>` marker (⚠ Warn).

Every finding carries a confidence label (`high` / `medium` / `low`).

## Override markers

Suppress a finding when a legitimate override exists, with a reason in
the code itself:

```csharp
// tenant-override: admin dashboard aggregates across academies
var allStudents = _db.Students.IgnoreQueryFilters().ToList();
```

```csharp
// across-tenants: internal health-check endpoint
[Authorize(Roles = "Admin")]
public IActionResult GlobalHealth() { ... }
```

An empty marker (no reason) is rejected. The reason is audited, not
just the marker, so future readers see *why*.

## Overrides (patterns)

- `docs/audit-tenant/patterns.md` — append repo-specific
  entity names, admin role markers, ownership helper names.

## Review before merge

In multi-tenant code, treat every 🚫 Block as a merge blocker unless
you can point to an override marker with a clear reason. ⚠ Warn
findings deserve attention but are defense-in-depth, not blockers.
