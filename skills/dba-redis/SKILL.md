---
name: dba-redis
description: >
  Redis heuristics catalogue for the dba role. Detects key
  design, TTL discipline, hot/big key risks, persistence
  trade-offs, pub/sub vs streams, pipeline use, eviction policy,
  and operational hazards. Every finding ships with a Redis
  command or config fix.
triggers:
  paths:
    - "redis/**"
  keywords: ["redis", "StackExchange.Redis", "ioredis", "redis-py", "ZADD", "SETEX", "HSET"]
  tools: []
pre_pass:
  file_patterns: "redis|\\.redis(\\.conf)?$"
  line_patterns: "KEYS\\s|SCAN\\s|EXPIRE|SETEX|ZADD|HSET|MULTI|PIPELINE"
---

# DBA — Redis Heuristics

## When to Engage

Invoked by the `dba` role when the diff touches Redis files or
Redis client usage according to the engine-detection convention
in `roles/dba.md`. Not invoked directly by the user.

## Connection (optional)

If `REDIS_URL` is set in `.env.octopus`, enrich the review by
running:

- `INFO` — version, memory, clients, persistence config
- `INFO memory` — `used_memory`, fragmentation ratio
- `MEMORY USAGE <key>` — actual size of a sample key
- `CLIENT LIST` — open connections
- `DBSIZE` — total key count
- `CONFIG GET maxmemory-policy` — eviction policy

If the env var is missing, emit one `QUESTION` for the engine and
proceed with static analysis only.

## Heuristics Catalogue

### Key design

- **No naming convention** — keys like `user1`, `data:5`, `temp`
  collide and are unobservable. Use a prefix scheme:
  `<app>:<entity>:<id>` (e.g., `octopus:session:abc123`).
- **Variable substitution risk** — interpolating user input
  directly into a key (`session:${userInput}`) without
  sanitization can collide intentionally; treat as input
  validation.
- **Excessively long keys** — keys themselves cost memory; long
  prefixes repeated millions of times are wasteful.

### TTL discipline

- **`SET` without `EX` on ephemeral data** — sessions, caches,
  rate-limiters must have an expiry. Without `EX`, the key
  persists forever and eventually fills memory.
- **`EXPIRE` called after `SET` (race)** — two-call form leaves a
  window where the key has no TTL. Use `SET key value EX seconds`
  (atomic).
- **TTL too short / too long** — flag obvious mismatches
  (1-second cache, 30-day session).
- **PERSIST** removes TTL — flag uses unless explicitly justified.

### Big keys

- **Unbounded list/set/hash growth** — `LPUSH` / `SADD` / `HSET`
  in a loop without trimming. Use `LTRIM`, periodic cleanup, or
  bounded ZSETs.
- **`MGET` / `HGETALL` on a giant hash** — `HGETALL` on a
  100k-field hash blocks the event loop. Use `HSCAN` for large
  hashes.
- **Big-key detection** — if connected, sample `MEMORY USAGE`
  on suspicious keys.

### Hot keys

- **Counter contention** — a single counter incremented from many
  clients (`INCR counter:global`) is a hot spot. Shard:
  `INCR counter:global:${rand(16)}` and sum on read.
- **Pub/sub on a single channel with many subscribers** — every
  publish fans out to every subscriber synchronously; consider
  streams with consumer groups.
- **Lua script holding the event loop** — Redis Lua is
  single-threaded; long scripts block everything.

### Persistence

- **No persistence configured** — `appendonly no` and no RDB
  snapshots means a restart loses everything. Document if
  intentional (cache-only deploy).
- **AOF without `appendfsync everysec`** — `appendfsync always`
  is durable but slow; `appendfsync no` defers to the OS (lose
  up to 30s on crash). `everysec` is the standard balance.
- **RDB snapshot interval mismatch** — `save 900 1` (every 15min
  if 1 key changed) is the default; flag if data loss tolerance
  is tighter.

### Pub/sub vs streams

- **Pub/sub for delivery guarantees** — pub/sub is
  fire-and-forget; subscribers that are offline miss messages.
  Use Streams (`XADD` / `XREADGROUP`) with consumer groups for
  durability.
- **Streams without `MAXLEN`** — `XADD stream * ...` grows
  unbounded. Use `XADD stream MAXLEN ~ 100000 * ...` to cap.

### Pipeline / batching

- **N-round-trip pattern** — a loop issuing single commands when
  a pipeline / `MGET` / `HMSET` would batch. Flag and suggest
  pipelining.
- **`MULTI`/`EXEC` for atomicity vs pipelining for speed** —
  flag confusion: `MULTI` provides atomicity, pipelining alone
  does not. Choose intentionally.

### Eviction policy

- **`maxmemory-policy noeviction`** — once memory is full, writes
  fail. Acceptable for a primary store, dangerous for a cache.
  Caches should use `allkeys-lru` or `allkeys-lfu`.
- **`volatile-lru` without setting TTL** — only evicts keys with
  a TTL. If most keys have none, the policy is useless.

### Operational hazards

- **`KEYS *` in production code** — blocks Redis for the
  duration of the scan. Use `SCAN` with a cursor.
- **`FLUSHALL` / `FLUSHDB` in code** — flag any non-test path
  that calls these.
- **`DEBUG SLEEP`** in production code — denial of service.
- **`DEBUG SEGFAULT`** — crashes Redis.
- **`CONFIG SET`** in application code — runtime config drift
  from the deployed `redis.conf`.

### Security of data

- **PII in keys** (`session:email@user.com`) — keys appear in
  `CLIENT LIST`, slow log, and persistence files. Hash the
  identifier.
- **No `requirepass` / ACL** — flag connections without
  authentication.
- **No TLS** in connection string (`rediss://` or `tls=true`) —
  flag.
- **Lua scripts trusting client input** — Lua runs server-side
  with full access; sanitize.

## Severity Mapping

| Finding | Default severity |
|---|---|
| `KEYS *` in production code | BLOCKING |
| `FLUSHALL`/`FLUSHDB` in non-test path | BLOCKING |
| `SET` without `EX` on ephemeral data (session/cache/rate-limit) | BLOCKING |
| Unbounded stream (`XADD` without `MAXLEN`) | BLOCKING |
| Pub/sub for messages that need delivery guarantees | BLOCKING |
| Hot counter without sharding | BLOCKING |
| Unbounded list/set/hash growth | BLOCKING |
| `maxmemory-policy noeviction` on cache deployment | BLOCKING |
| PII in keys | BLOCKING |
| Connection without auth or TLS | BLOCKING |
| `EXPIRE` after `SET` instead of atomic `SET ... EX` | ADVISORY |
| Missing naming convention | ADVISORY |
| `HGETALL` on potentially large hash | ADVISORY |
| Non-pipelined N-round-trip loop | ADVISORY |
| Cannot determine memory pressure without `REDIS_URL` | QUESTION |

## Output Snippet

Each finding contributes a row to the `dba` role's findings table:

```
| BLOCKING | Redis | src/cache/session.ts:12 | SET on session key has no TTL — key persists forever and fills memory | SET session:${id} ${value} EX 3600 |
```
