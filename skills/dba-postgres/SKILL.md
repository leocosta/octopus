---
name: dba-postgres
description: >
  PostgreSQL heuristics catalogue for the dba role. Detects
  indexing, modeling, query, migration, retention, capacity,
  security, and concurrency problems specific to Postgres. Every
  finding ships with a SQL fix.
triggers:
  paths:
    - "db/postgres/**"
    - "migrations/**/*.sql"
  keywords: ["SERIAL", "RETURNING", "JSONB", "pg_", "CONCURRENTLY", "VACUUM"]
  tools: []
pre_pass:
  file_patterns: "postgres|pg_|\\.sql$"
  line_patterns: "SERIAL|JSONB|RETURNING|CONCURRENTLY|FOR UPDATE|CTE"
---

# DBA — PostgreSQL Heuristics

## When to Engage

Invoked by the `dba` role when the diff touches Postgres files
according to the engine-detection convention in `roles/dba.md`.
Not invoked directly by the user.

## Connection (optional)

If `DATABASE_URL` is set in `.env.octopus`, enrich the review by
querying:

- `pg_indexes` — existing indexes per table
- `pg_stat_user_indexes` — index usage statistics (find unused
  indexes via `idx_scan = 0`)
- `pg_stat_user_tables` — row counts, dead tuples, last vacuum
- `EXPLAIN (ANALYZE, BUFFERS)` on representative queries
- `pg_locks` — long-held locks
- `pg_size_pretty(pg_total_relation_size(...))` — table footprint

If the env var is missing, emit one `QUESTION` for the engine and
proceed with static analysis only.

## Heuristics Catalogue

### Indexing

- **FK without index** — Postgres does not auto-index FK target
  columns (unlike the constraint side). Every `REFERENCES` column
  needs `CREATE INDEX ... ON child(parent_id);`. Without it,
  cascading delete and JOINs full-scan.
- **`SERIAL` in new code** — use `GENERATED ALWAYS AS IDENTITY`
  (SQL standard, no underlying sequence-ownership gotchas).
- **B-tree on a high-cardinality range column with skewed data** —
  consider `BRIN` for append-only timestamp columns.
- **`@>`, `?`, `?&`, `?|` on JSONB without GIN** — `WHERE data @>
  '{"k":"v"}'` without `CREATE INDEX ... USING GIN (data)` is a
  full scan.
- **`LIKE 'prefix%'` without `text_pattern_ops`** — needs
  `CREATE INDEX ... ON t(col text_pattern_ops);` to be used in
  non-C locales.
- **Partial index opportunity** — `WHERE deleted_at IS NULL` queries
  on a soft-delete table → `CREATE INDEX ... ON t(col) WHERE
  deleted_at IS NULL;`.
- **Composite index order** — equality before range, most
  selective first.
- **Unused indexes from prior migrations** — drop via the connected
  pass (`idx_scan = 0` for 30 days).

### Modeling

- **`VARCHAR(n)` with arbitrary `n`** — prefer `TEXT` with a
  `CHECK (length(col) <= n)` if a bound matters; Postgres stores
  both identically.
- **`TIMESTAMP` without `TIMESTAMPTZ`** — always use `TIMESTAMPTZ`
  for points in time; `TIMESTAMP` discards the offset and
  re-interprets in the session's timezone.
- **`MONEY` type** — do not use; use `NUMERIC(p,s)` (see
  `audit-money`).
- **`JSONB` as a schema dump** — flag if a `JSONB` column is the
  primary storage for fields that have a stable shape; that is
  not what JSONB is for.
- **`UUID` as primary key without `gen_random_uuid()`** — random
  v4 UUIDs are fine for distribution but bad for B-tree locality;
  consider UUID v7 or a `BIGINT IDENTITY` if write rate is high.
- **Missing `NOT NULL`** on columns the domain requires; default
  values count as a discovery, not justification for nullability.
- **Missing `CHECK` constraints** for enum-like columns; the type
  system inside Postgres is a feature, use it.

### Query patterns

- **`SELECT *` in production paths** — defeats index-only scans
  and pollutes plans when columns change.
- **N+1 in ORM-generated queries** — flag patterns where the diff
  introduces a loop over results issuing per-row reads.
- **No `LIMIT` on list-bound queries** — every list path must be
  paginated.
- **`OFFSET` for deep pagination** — switch to keyset pagination
  (`WHERE (created_at, id) < (?, ?) ORDER BY ... LIMIT ?`).
- **`SELECT ... FOR UPDATE` outside a transaction** — meaningless;
  flag.
- **CTEs as fences** — pre-PG12, CTEs were optimization fences.
  In modern PG they inline by default unless `MATERIALIZED`.
  Verify the version assumption.
- **Aggregations over JSONB without index** — `WHERE data->>'k'
  = 'v'` on a hot path needs a functional index or extract the
  column.

### Migration safety

- **`CREATE INDEX` without `CONCURRENTLY` on large tables** —
  takes an `ACCESS EXCLUSIVE` lock; the build blocks writes for
  the duration. Use `CREATE INDEX CONCURRENTLY ...` (cannot run
  inside a transaction).
- **`ALTER TABLE ADD COLUMN NOT NULL` without default** — pre-PG11
  rewrites the entire table under exclusive lock. PG11+ with a
  non-volatile default is fast, but check the project's PG
  version.
- **`ALTER TABLE ... ALTER COLUMN TYPE`** — full table rewrite
  with exclusive lock. Split into add-column → backfill →
  swap-views/rename.
- **Rename column / drop column** — multi-step deploy: ensure no
  code reads/writes the old name in any deployed version.
- **Migration in a single transaction with `CREATE INDEX
  CONCURRENTLY`** — not allowed; the migration runner must split.
- **Long-running backfill in one statement** — batch in chunks
  (`UPDATE ... WHERE id BETWEEN ? AND ?` with a loop) to avoid
  bloat and long locks.

### Retention / lifecycle

- **Append-only table without partitioning plan** — flag any
  log/event/audit table likely to exceed 10M rows without
  declarative partitioning.
- **No archival path for soft-deleted rows** — soft-deletes
  accumulate forever; document either an archive-and-purge job
  or accept the bloat.

### Capacity / growth

- **Unbounded growth column** — `TEXT` column accepting user
  input without a length check.
- **Hot tuples** — counters incremented row-by-row create dead
  tuples faster than autovacuum can keep up. Consider
  table-partitioned counters or a redis-backed counter with
  periodic flush.

### Security of data

- **PII in indexed columns** without an explicit reason —
  `email`, `cpf`, `phone` in btree index keys persists
  unencrypted copies.
- **Row-level security off** in a multi-tenant table — even with
  application filters, defence-in-depth wants `ENABLE ROW LEVEL
  SECURITY` plus a tenant policy. Cross-check with
  `audit-tenant`.
- **`SECURITY DEFINER` function** without an explicit `SET
  search_path = pg_catalog, public` — search-path injection
  attack vector.
- **Connection without `sslmode=require`** — flag connection
  strings missing it.

### Concurrency

- **Missing `SET LOCAL ...` for isolation in functions** — make
  isolation level explicit at the transaction boundary.
- **Long transactions holding locks** — flag transactions that
  span HTTP calls, queue publishes, or human input.
- **`SELECT ... FOR UPDATE SKIP LOCKED`** — correct for queue
  workers; flag if used outside that pattern (silent skipping
  of rows is surprising).
- **Advisory locks without cleanup** — `pg_advisory_lock` without
  matching `pg_advisory_unlock` on every code path.

## Severity Mapping

| Finding | Default severity |
|---|---|
| FK without index on join-critical column | BLOCKING |
| `CREATE INDEX` without `CONCURRENTLY` on large table | BLOCKING |
| `ALTER COLUMN TYPE` on hot table without split | BLOCKING |
| `SELECT *` in production path | BLOCKING |
| `TIMESTAMP` instead of `TIMESTAMPTZ` for a time point | BLOCKING |
| PII in non-encrypted indexed column | BLOCKING |
| RLS off on multi-tenant table | BLOCKING |
| Append-only table > 10M rows without retention plan | BLOCKING |
| `SERIAL` in new code instead of `IDENTITY` | ADVISORY |
| `VARCHAR(n)` with arbitrary `n` | ADVISORY |
| Composite index ordering suboptimal | ADVISORY |
| `OFFSET` deep pagination | ADVISORY |
| Cannot determine table size without `DATABASE_URL` | QUESTION |

## Output Snippet

Each finding contributes a row to the `dba` role's findings table:

```
| BLOCKING | Postgres | migrations/V0042__add_orders.sql:18 | FK orders.customer_id not indexed — JOINs from customers will full-scan | CREATE INDEX CONCURRENTLY idx_orders_customer_id ON orders(customer_id); |
```
