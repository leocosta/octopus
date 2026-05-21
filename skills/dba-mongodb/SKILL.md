---
name: dba-mongodb
description: >
  MongoDB heuristics catalogue for the dba role. Detects indexing
  (ESR rule), modeling (embed vs reference), query, migration,
  retention (TTL), capacity (shard key), security, and concurrency
  problems. Every finding ships with a Mongo shell command.
triggers:
  paths:
    - "db/mongo/**"
    - "schemas/mongo/**"
  keywords: ["db.collection", "aggregate", "createIndex", "bulkWrite", "changeStream"]
  tools: []
pre_pass:
  file_patterns: "mongo|\\.mongo\\.(json|js|ts)$"
  line_patterns: "db\\.\\w+\\.|aggregate\\(|createIndex|bulkWrite|\\$match|\\$lookup"
---

# DBA — MongoDB Heuristics

## When to Engage

Invoked by the `dba` role when the diff touches MongoDB files
according to the engine-detection convention in `roles/dba.md`.
Not invoked directly by the user.

## Connection (optional)

If `MONGODB_URI` is set in `.env.octopus`, enrich the review by
querying:

- `db.collection.getIndexes()` — existing indexes
- `db.collection.stats()` — size, document count, average size
- `db.collection.aggregate([...]).explain("executionStats")` —
  index usage on representative pipelines
- `db.serverStatus().opcounters` — read/write pattern
- `db.currentOp()` — long-running ops

If the env var is missing, emit one `QUESTION` for the engine and
proceed with static analysis only.

## Heuristics Catalogue

### Indexing

- **No index on query predicate** — every `find()` / `$match` on
  a hot path must hit an index. Default `_id` does not save you
  on other predicates.
- **ESR rule violation** — composite indexes order:
  **E**quality → **S**ort → **R**ange. A query like
  `find({status: "open"}).sort({createdAt: -1}).limit(20)` wants
  `{status: 1, createdAt: -1}`, not `{createdAt: -1, status: 1}`.
- **Index direction wrong for sort** — `{createdAt: 1}` does not
  support `sort({createdAt: -1})` efficiently on compound
  indexes; the direction matters when combined with other keys.
- **Missing index on `$lookup` foreign field** — every `$lookup`
  needs an index on the joined collection's join field, or it
  is a full scan per source document.
- **`$regex` without anchor** — `^prefix` is index-usable;
  `contains` is not. Flag any unanchored regex on a hot path.
- **TTL index on the wrong field** — TTL is on a single date
  field; if the data has a derived expiry, store it as a real
  field.
- **Too many indexes** — every index costs writes and RAM. Flag
  collections with >10 user indexes; revisit.
- **Wildcard index abuse** — wildcard indexes are powerful but
  expensive; document the justification.

### Modeling

- **Embed vs reference** — embed when the child is read with the
  parent and bounded in size; reference when the child is
  queried independently, unbounded, or shared. Flag embeds in
  hot collections that grow without bound (comments, log
  entries, audit trails).
- **Document size approaching 16MB** — flag any collection where
  documents are growing unboundedly (arrays without trim policy).
- **`_id` as a domain key** — `_id` is sacred (immutable,
  primary). Avoid using a meaningful business identifier;
  prefer ObjectId and a separate indexed field.
- **No schema validator** — production collections benefit from
  `validator: { $jsonSchema: { ... } }`. Catches drift early.
- **`$type` mismatch** — fields silently storing mixed types
  (string sometimes, ObjectId other times) cause subtle bugs
  and break indexes.
- **Missing `required` in validator** — every domain-required
  field should be `required` in the JSON schema.

### Query patterns

- **`find({})` without `limit()`** — unbounded result sets.
  Pagination via `_id`-based keyset preferred over `skip()`.
- **`skip()` for deep pagination** — `skip(n)` reads and discards
  n documents. Use keyset:
  `find({_id: { $gt: lastId }}).sort({_id: 1}).limit(n)`.
- **Aggregation pipeline without `$match` first** — `$match`
  early uses indexes; later in the pipeline it does not.
- **`$lookup` on cold collection** — equivalent to a JOIN to an
  unindexed table; ensure foreign field is indexed.
- **`$unwind` of large arrays** — explodes the document count;
  rethink modeling.
- **`upsert: true` without uniqueness index** — race condition
  creates duplicates.

### Migration safety

- **Mass `updateMany` without batching** — splits into chunks;
  Mongo migrations are not transactional across all docs unless
  in a multi-doc transaction (which has its own costs).
- **Index build without `background: true` on pre-4.2** — blocks
  writes. On 4.2+ all index builds are hybrid by default;
  document the version.
- **Adding required field to a validator** — existing documents
  fail validation. Either accept missing-or-present, or backfill
  first.
- **Dropping a collection that still has reads** — multi-step:
  stop reads → wait → drop.
- **`renameCollection` across databases** — copies data and
  invalidates open cursors.

### Retention / lifecycle

- **Log/event collection without TTL** — every log-shaped
  collection (events, sessions, audit) needs a TTL index:
  `db.events.createIndex({ createdAt: 1 }, { expireAfterSeconds: 2592000 })`.
- **TTL on a slow tick** — TTL runs every 60s; documents may
  persist briefly past expiry. Document the bound.
- **No archival policy for cold data** — collections that
  outgrow the working set benefit from time-series partitioning
  (Mongo 5.0+) or a separate cold-storage path.

### Capacity / growth

- **Shard key chosen badly** — three properties matter:
  cardinality (must be high), write distribution (must spread,
  not hotspot), query locality (queries must hit one or few
  shards). Flag:
  - Monotonic shard keys (`{createdAt: 1}`, `_id`) → all writes
    go to one shard
  - Low-cardinality shard keys (`{tenantId: 1}` with 10 tenants)
    → cannot rebalance
  - Shard key that requires scatter-gather for every query
- **Unbounded array growth** — `comments: []` inside a parent
  document; eventually hits 16MB ceiling.
- **Working set exceeds RAM** — flag any collection design that
  guarantees the working set is larger than typical instance
  RAM (frequent eviction → slow reads).

### Security of data

- **PII in indexed fields** — `email`, `cpf`, `phone` in index
  keys. Consider hash + separate lookup.
- **`find()` without tenant filter** — multi-tenant collections
  must be queried with a tenant predicate; cross-check with
  `audit-tenant`.
- **No `authMechanism`** in connection string — flag.
- **No TLS** in connection string (`tls=true` or `ssl=true` per
  driver) — flag.
- **Field-level encryption needed but absent** — if PII columns
  are stored, consider client-side field-level encryption.

### Concurrency

- **Multi-document transaction without justification** — cost is
  real (oplog, retries, lock contention). Document the
  consistency requirement that justifies it.
- **`findAndModify` instead of `updateOne` with return** — old
  style; the modern API is clearer.
- **No `writeConcern: "majority"` for critical writes** — silent
  rollback risk on primary failure.

## Severity Mapping

| Finding | Default severity |
|---|---|
| No index on hot-path query predicate | BLOCKING |
| ESR rule violation on compound index | BLOCKING |
| Monotonic or low-cardinality shard key | BLOCKING |
| `find()` without limit on production path | BLOCKING |
| Log collection without TTL | BLOCKING |
| Unbounded array embed | BLOCKING |
| PII in non-encrypted indexed field | BLOCKING |
| Tenant filter missing on multi-tenant collection | BLOCKING |
| `$lookup` foreign field not indexed | BLOCKING |
| `skip()` for deep pagination | ADVISORY |
| Missing schema validator | ADVISORY |
| `_id` as domain key | ADVISORY |
| Cannot determine collection stats without `MONGODB_URI` | QUESTION |

## Output Snippet

Each finding contributes a row to the `dba` role's findings table:

```
| BLOCKING | Mongo | db/mongo/orders.js:24 | Composite index {createdAt:-1, customerId:1} violates ESR (customerId is equality) | db.orders.dropIndex("createdAt_-1_customerId_1"); db.orders.createIndex({customerId: 1, createdAt: -1}); |
```
