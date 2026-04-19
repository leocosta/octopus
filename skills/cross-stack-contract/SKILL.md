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
