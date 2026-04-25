# Tenant-Scope-Audit Patterns (default)

> Embedded default. Override at `docs/tenant-scope-audit/patterns.md`.
> Overrides append; they do not replace the defaults.

## Path tokens

tenant, multitenant, tenancy, organization, workspace, academy, scope

## Content regex

- `IgnoreQueryFilters`
- `FromSqlRaw|FromSqlInterpolated|ExecuteSqlRaw|ExecuteSqlInterpolated`
- `tenant_id|tenantid|org_id|organization_id|workspace_id`
- `AllTenants|CrossTenant|SuperAdmin`

## Tenant field names (T3 raw SQL check)

Recognized tenant column names (case-insensitive substring match
inside raw SQL string literals):

- `tenant_id`
- `tenantid`
- `academy_id` (Tatame-specific example)
- `org_id`
- `organization_id`
- `workspace_id`

## Admin role markers (T6 cross-tenant admin check)

Claims and attribute values that indicate admin/cross-tenant access:

- `[AllowAnonymous]`
- `[Authorize(Roles = "Admin")]`
- `[Authorize(Roles = "SuperAdmin")]`
- `[Authorize(Policy = "CrossTenant")]`
- `@UseGuards(AdminGuard)` (NestJS bridge — v2)

## Override marker comments

These preceding-line comments suppress findings with justification:

- `// tenant-override: <reason>` — suppresses T1 for
  `IgnoreQueryFilters()`.
- `// across-tenants: <reason>` — suppresses T6 on admin endpoints.

Both markers require text after the colon; an empty marker
(`// tenant-override:`) is rejected as invalid.

## Ownership helper names (T4)

When a controller action takes `id` from the route and calls one of
these on a tenant-scoped DbSet, the finding is suppressed (the helper
is assumed to enforce ownership):

- `EnsureOwned`, `EnsureOwnedBy`, `EnsureOwnedByTenant`
- `OwnedOrThrow`
- `AssertOwnedBy`

## Raw SQL helpers

Recognized EF methods for T3:

- `FromSqlRaw`, `FromSqlInterpolated`
- `ExecuteSqlRaw`, `ExecuteSqlInterpolated`
- `Database.SqlQuery`, `Database.ExecuteSqlRaw`
