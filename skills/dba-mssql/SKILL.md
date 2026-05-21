---
name: dba-mssql
description: >
  MSSQL heuristics catalogue for the dba role. Detects indexing,
  modeling, query, migration, retention, capacity, security, and
  concurrency problems specific to SQL Server. Every finding ships
  with a T-SQL fix.
triggers:
  paths:
    - "db/mssql/**"
    - "migrations/mssql/**"
  keywords: ["IDENTITY", "NVARCHAR", "dbo.", "sp_executesql", "WITH (NOLOCK)", "GO"]
  tools: []
pre_pass:
  file_patterns: "mssql|sqlserver|\\.sql$"
  line_patterns: "IDENTITY|NVARCHAR|\\[dbo\\]|sp_executesql|NOLOCK|ROWLOCK|PAGLOCK"
---

# DBA — MSSQL Heuristics

## When to Engage

Invoked by the `dba` role when the diff touches MSSQL files
according to the engine-detection convention in `roles/dba.md`.
Not invoked directly by the user.

## Connection (optional)

If `MSSQL_CONNECTION_STRING` is set in `.env.octopus`, enrich the
review by querying:

- `sys.indexes` and `sys.index_columns` — existing indexes per
  table
- `sys.dm_db_index_usage_stats` — unused indexes (last seek/scan
  in the past 30 days)
- `sys.dm_db_missing_index_details` — suggested missing indexes
- `sp_spaceused '<table>'` — row count and storage footprint
- `SET STATISTICS XML ON` / showplan for representative queries

If the env var is missing, emit one `QUESTION` for the engine and
proceed with static analysis only.

## Heuristics Catalogue

### Indexing

- **FK without index** — every foreign key column needs an index.
  Without it, every JOIN from the parent table is a full scan.
  Fix: `CREATE NONCLUSTERED INDEX IX_<table>_<col> ON dbo.<table>(<col>);`
- **Clustered index on a random key** — clustered on `UNIQUEIDENTIFIER`
  with `NEWID()` (not `NEWSEQUENTIALID()`) causes page splits on
  every insert. Fix: switch to `NEWSEQUENTIALID()` or use an
  `IDENTITY INT/BIGINT` clustered key.
- **Composite index order** — equality columns before range columns,
  most selective first. A composite `(status, created_at)` for
  `WHERE status = 'open' AND created_at > ?` is correct; reversed
  is not.
- **Duplicate / redundant indexes** — a covering index that fully
  contains another's key prefix supersedes it. Drop the smaller.
- **Filtered indexes missed** — `WHERE deleted = 0` queries on a
  soft-delete table benefit from a filtered index:
  `CREATE INDEX IX_... ON dbo.<t>(<col>) WHERE deleted = 0;`
- **Include columns for covering** — when the query selects a few
  extra columns, prefer `INCLUDE (<cols>)` over widening the key.
- **Fill factor on hot tables** — default 100 fill factor on a
  table with constant inserts in the middle causes page splits;
  flag if reads dominate and the table is wide.

### Modeling

- **`NVARCHAR(MAX)` for short strings** — use `NVARCHAR(<n>)` with
  a real bound; MAX values are stored off-row and cannot be
  indexed normally.
- **`VARCHAR` for Unicode-bearing data** — use `NVARCHAR` (or
  `VARCHAR` with explicit collation) — silent data corruption
  otherwise.
- **`FLOAT`/`REAL` for money** — use `DECIMAL(p,s)` (see
  `audit-money` for fuller coverage).
- **`DATETIME` instead of `DATETIME2`** — `DATETIME2` is more
  precise and uses less storage for high precision needs.
- **No `IDENTITY` or natural key** — composite natural keys are
  fine if stable; ad-hoc string keys generated client-side are
  not.
- **Missing `NOT NULL` on required columns** — every column with
  a domain requirement of "always present" must be `NOT NULL`;
  defaulting at the application layer is not enough.

### Query patterns

- **`SELECT *`** — name the columns. Index-only scans become
  impossible otherwise.
- **`WITH (NOLOCK)`** — equivalent to `READ UNCOMMITTED`; returns
  uncommitted data and may double-read or miss rows. Use
  `READ COMMITTED SNAPSHOT` at the database level instead. BLOCKING
  if used in financial / transactional paths.
- **Implicit conversion** — `WHERE varchar_col = N'value'` (or
  `int_col = '5'`) defeats index seek. Match types exactly.
- **`OR` over different columns** — rewrite as `UNION ALL` with
  separate index seeks, or add a covering composite.
- **Scalar UDF in WHERE** — kills parallelism and forces row-by-row
  evaluation. Inline the logic or use an inline table-valued
  function.

### Migration safety

- **`ALTER COLUMN ... NOT NULL` on hot table without default** —
  schema-modification lock for the duration of the rewrite. Split
  into: add nullable copy → backfill in batches → set NOT NULL →
  swap.
- **`CREATE INDEX` without `WITH (ONLINE = ON)`** — Enterprise
  edition supports online index builds; Standard/Express do not.
  Flag both: missing `ONLINE = ON` on Enterprise (avoidable lock)
  and a long index build on Standard (warn the team about the
  outage window).
- **`DROP COLUMN` directly** — make it nullable, deploy the code
  that stops writing, then drop in a later migration.
- **Non-idempotent migration** — wrap in `IF NOT EXISTS` / `IF
  EXISTS` checks. Re-running must be a no-op.
- **`UPDATE` over the whole table** — batch in chunks of N rows
  with a loop; whole-table updates escalate locks to table level.

### Retention / lifecycle

- **Append-only table without partitioning plan** — flag any
  log/event/audit table expected to grow past 10M rows without a
  partitioning, archival, or rollover plan.
- **`TRUNCATE TABLE`** without considering FK constraints (cannot
  truncate referenced tables).

### Capacity / growth

- **Last-page insert contention** — `IDENTITY` on a clustered key
  with very high write rate causes hotspotting on the last page.
  Consider partitioning or a more spread key.
- **`UNIQUEIDENTIFIER` clustered** — see above; storage
  fragmentation grows without bound.

### Security of data

- **PII in indexed columns** — `email`, `cpf`, `ssn`, `phone` in
  an index key persists copies; consider hash-based lookup or
  encrypted columns.
- **Connection without `Encrypt=True`** — flag MSSQL connection
  strings without explicit TLS.
- **`sp_executesql` with string concatenation** — SQL injection
  vector. Use parameterized form: `sp_executesql N'... @p1 ...',
  N'@p1 INT', @p1 = @value`.

### Concurrency

- **Implicit transaction wrapping HTTP/IO** — flag any transaction
  that spans network calls outside the database.
- **Missing isolation declaration** — explicit
  `SET TRANSACTION ISOLATION LEVEL READ COMMITTED` (or whichever)
  at the start of any procedure that does multi-statement work.
- **Lock hint abuse** — `WITH (TABLOCK)`, `WITH (XLOCK)` in
  routine queries.

## Severity Mapping

| Finding | Default severity |
|---|---|
| FK without index on join-critical column | BLOCKING |
| `WITH (NOLOCK)` in financial path | BLOCKING |
| `ALTER COLUMN NOT NULL` on hot table without split plan | BLOCKING |
| `SELECT *` in production path | BLOCKING |
| PII in non-encrypted indexed column | BLOCKING |
| `sp_executesql` with string concat | BLOCKING |
| Append-only table > 10M rows without retention plan | BLOCKING |
| Missing `WITH (ONLINE = ON)` on Enterprise | ADVISORY |
| Composite index ordering suboptimal but works | ADVISORY |
| `DATETIME` vs `DATETIME2` | ADVISORY |
| Missing isolation declaration | ADVISORY |
| Cannot determine table size without `MSSQL_CONNECTION_STRING` | QUESTION |

## Output Snippet

Each finding contributes a row to the `dba` role's findings table:

```
| BLOCKING | MSSQL | db/mssql/V0042__add_orders.sql:14 | FK orders.customer_id without index; full scan on JOIN from customers | CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON dbo.Orders(CustomerId) WITH (ONLINE = ON); |
```
