---
name: cross-stack-contract
description: >
  Detect API-vs-frontend contract drift in multi-stack monorepos
  (.NET/Node API + React/Vue/Astro frontends). Given a branch or PR,
  flags endpoint additions without consumers, removals/renames that
  break callers, DTO/enum field drift, status-code changes, auth-rule
  changes, and param changes. Produces a severity-tiered report with
  confidence labels.
---

# Cross-Stack Contract Protocol

## Overview

This skill detects drift between stack boundaries in a monorepo. It
resolves the target ref, partitions changed files by stack
(api/app/lp), extracts contract "intent" tokens from the API diff
(endpoint paths, DTO names, enum names, auth attributes, params), and
grep-matches them against frontend usage.

It does not generate types. It does not run contract tests. It finds
drift before merge.

Architecturally it mirrors `money-review`: pure-markdown skill +
templates + slash command + wizard registration. Output format is
compatible so reports can be concatenated in a single PR comment.

## Invocation

```
/octopus:cross-stack-contract [ref] [--base=main] [--stacks=<list>] [--only=<checks>] [--write-report]
```

**Arguments / options:**

- `ref` (optional) — PR (`#123`/URL), branch name, or commit SHA.
  Default: current HEAD vs its upstream.
- `--base=<branch>` — base for the diff. Default: `main`.
- `--stacks=<list>` — comma-separated subset of stacks (`api`, `app`,
  `lp`, or custom names from `.octopus.yml`). Default: all detected.
- `--only=<list>` — comma-separated subset of checks:
  `endpoint-added,endpoint-removed,dto,enum,status,auth,params`.
- `--write-report` — also save
  `docs/reviews/YYYY-MM-DD-contract-<slug>.md`.

## Stack Discovery

Resolve stack roots in this order:

1. **Manifest override.** `.octopus.yml` may declare:
   ```yaml
   stacks:
     api: api/src
     app: app/src
     lp: lp/src
   ```
   Keys are role names; values are repo-relative paths. The role names
   `api`, `app`, and `lp` are conventional — any other names are
   accepted and treated as additional stacks.

2. **Autodetection** (used when the manifest has no `stacks:` map):
   - `api` — first directory containing `*.csproj`, `*.sln`, or a
     `package.json` whose `dependencies` include `express`, `fastify`,
     `hono`, or `@nestjs/core`. Probe order: `api/`, `apps/api/`,
     `backend/`, `server/`.
   - `app` — first directory with a `package.json` whose
     `dependencies` include `react`, `vue`, or `@angular/core`. Probe
     order: `app/`, `apps/app/`, `frontend/`, `web/`.
   - `lp` — first directory with `astro.config.*` or `next.config.*`
     that is distinct from `app`. Probe order: `lp/`, `apps/lp/`,
     `landing/`, `site/`.

3. **Unresolvable role** — warn and skip. If fewer than two stacks
   resolve, the skill aborts (nothing to compare).

Override patterns live at:

- `docs/cross-stack-contract/patterns.md` (canonical)
- `docs/CROSS_STACK_CONTRACT_PATTERNS.md` (uppercase compat)
- `skills/cross-stack-contract/templates/patterns.md` (embedded default)

Override files **append** to the defaults.

## Inspection Checks

For each check, the skill extracts "intent" tokens from the API diff
(endpoint paths, DTO/record names, enum names, route attributes, auth
annotations, param lists) and greps the frontend stacks for usage.

Every finding is labeled with a **confidence** level:
- `high` — exact match on both sides (same URL string, same symbol name).
- `medium` — partial match (same symbol, different file; or path differs
  in one segment).
- `low` — heuristic match only (e.g. camelCase of a path).

Families are skippable via `--only`.

### C1 endpoint-added — new endpoint without a consumer

Detect new controller methods / route attributes / minimal-API
registrations added in the API diff. For each:

- Build a URL signature: method (GET/POST/...) + normalized path.
- Grep each frontend stack for a matching `fetch(...)`, `axios.*`,
  `ky.*`, `useApi(...)`, or equivalent call site.
- If no consumer is found, emit an **ℹ Info** finding. If the consumer
  is present in the same diff (same PR), no finding.

Severity: ℹ Info.

### C2 endpoint-removed — consumer still calls a gone endpoint

Detect endpoint removals or URL renames in the API diff. For each:

- Grep frontend stacks for the old URL.
- If any reference survives outside the diff, emit a **🚫 Block**.

Severity: 🚫 Block when a live consumer references the removed URL.

### C3 dto — DTO field change without frontend update

Identify DTO definitions in the API diff (records / classes used as
`[FromBody]` or as return types). For each:

- Build a field map (name, type) before and after.
- For each mutated field (added, removed, renamed, retyped):
  - Grep frontend stacks for an `interface <Name>`, `type <Name>`, or
    Zod schema with the same name.
  - If a frontend definition exists and the same diff did not touch it,
    emit a **⚠ Warn** citing both sides.
  - If no frontend definition is found, emit **ℹ Info** (may be a
    server-only DTO).

Severity: ⚠ Warn on drift, ℹ Info when nothing matches.

### C4 enum — enum values out of sync

Detect enum definitions added, removed, or with changed members in the
API diff. For each:

- Grep frontend stacks for a TS `enum`, union type, or `as const` map
  with the same name.
- Emit **⚠ Warn** when the frontend definition does not mirror the new
  member set.

Severity: ⚠ Warn.

### C5 status — response status code changed

Detect status code changes on existing endpoints:
- `return Ok(...)` ↔ `return Created(...)` / `return NoContent()`.
- New `throw new ConflictException`, `BadRequestException`, or a
  middleware that newly returns a 4xx on the endpoint path.

- Grep frontend handlers for `response.status`, `error.status`,
  `err.response?.status` referencing the endpoint.
- Emit **ℹ Info** summarizing the status change and the nearest
  frontend handler for manual review.

Severity: ℹ Info.

### C6 auth — authorization rule change

Detect `[Authorize]`, `[AllowAnonymous]`, `@UseGuards`, or middleware
order changes on an endpoint.

- Emit **⚠ Warn** unconditionally when an auth rule changes on an
  existing endpoint — the frontend must re-verify its token / login
  flow for that route.

Severity: ⚠ Warn.

### C7 params — path or query param changed (continued below)

<!-- keeps C7 header searchable; detail follows -->



Detect path params or query params added / removed / renamed on an
existing endpoint:
- `.../{id}/...` gained or lost a segment.
- `[FromQuery] string name` added or renamed.

- Grep frontend call sites for the old signature.
- Emit **⚠ Warn** when a live call site uses the old shape.

Severity: ⚠ Warn.

## Output

**Default (chat):** one markdown block with three severity headings,
each finding formatted as
`Cn **check** (confidence): <description> [api-file:line ↔ frontend-file:line]`.

```
## 🚫 Block (N)
- C2 **endpoint-removed** (high): `GET /students/{id}/profile` removed
  in `api/.../StudentsController.cs:82`, still called in
  `app/src/hooks/useStudentProfile.ts:14`.

## ⚠ Warn (N)
- C3 **dto** (medium): field `StudentDto.fullName` removed in
  `api/.../StudentDto.cs:9`, still declared in
  `app/src/types/student.ts:5`.

## ℹ Info (N)
- C1 **endpoint-added** (low): `POST /classes/{id}/archive` added;
  no consumer detected in app or lp.
```

Always end with:
`cross-stack-contract: N block, N warn, N info (<stacks compared>)`.

**With `--write-report`:** content is persisted to
`docs/reviews/YYYY-MM-DD-contract-<slug>.md` with frontmatter:

```yaml
---
ref: feat/api-v2
base: main
stacks: [api, app, lp]
generated_by: octopus:cross-stack-contract
generated_at: 2026-04-19
summary: "1 block, 2 warn, 1 info"
---
```

The slug is derived from the branch name or PR number (lowercase ASCII,
max 40 chars).

## Errors

- **No stacks detected** → abort with the message "add `stacks:` to
  `.octopus.yml` or run from a supported monorepo layout".
- **Only one stack detected** → print "nothing to compare" and exit 0
  with `cross-stack-contract: 0 block, 0 warn, 0 info`.
- **Base branch missing** → abort with `--base` hint.
- **No contract-relevant changes** → print "no contract changes
  detected" and exit 0.
- **Unrecognized `--only` check** → abort, list valid checks.

## Composition

Runs well alongside `money-review` and `security-scan`. All three emit
the same three-heading severity format so the reports can be
concatenated into a single PR comment without extra formatting work.

The findings are guidance, not a gate. Reviewers decide whether to
block, require changes, or accept with a note.
