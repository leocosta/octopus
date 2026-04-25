---
name: audit-all
description: >
  Run the four quality-audit skills in parallel against one ref —
  audit-security, audit-money, audit-tenant, review-contracts.
  Shared file discovery + parallel execution + consolidated report
  with a cross-audit hotspots table.
depends_on:
  - audit-security
  - audit-money
  - audit-tenant
  - review-contracts
triggers:
  paths: ["openapi/**", "contracts/**", "**/openapi.yaml", "**/openapi.json"]
  keywords: ["auth", "jwt", "payment", "invoice", "stripe", "tenant", "org", "workspace"]
  tools: []
---

# Audit-All Protocol

## Overview

This skill is a composer: it does not invent new audit logic. It
resolves the diff once, classifies each touched file into domain
tags, dispatches the four audit skills in parallel against their
domain-matching file subsets, then merges the four reports into a
single severity-tiered output with a cross-audit hotspots table.

The default path is deterministic — same inputs produce the same
set of files routed to the same audits. Copy inside each sub-report
comes from the underlying audit skill, unchanged.

## Invocation

```
/octopus:audit-all [ref] [--base=main] [--only=<audits>] [--write-report]
```

**Arguments / options:**

- `ref` (optional) — PR (`#123`/URL), branch name, or commit SHA.
  Default: current HEAD vs its upstream.
- `--base=<branch>` — base for the diff. Default: `main`.
- `--only=<list>` — comma-separated subset of
  `security,money,tenant,cross-stack`. Default: every audit whose
  skill is installed.
- `--write-report` — persist the consolidated report to
  `docs/reviews/YYYY-MM-DD-audit-all-<slug>.md`.

## Shared File Discovery

Run once at the start, before any audit:

1. `git diff --name-only <base>...<ref>` → list of touched files.
2. For each file, apply the domain-tag heuristics already published
   in the underlying audit skills' pattern templates (e.g.
   `skills/audit-money/templates/patterns.md`,
   `skills/audit-tenant/templates/patterns.md`). Do not copy
   the patterns here; reference them directly.
3. Produce a `file → [domains]` map. Domains in v1:
   `money`, `tenant`, `webhook`, `auth`, `api-contract`,
   `frontend-consumer`, `secrets`, `config`.

If the diff is empty, print `audit-all: no changes to review` and
exit 0. Do not proceed to dispatch.

## Parallel Execution

Dispatch four subagents via `superpowers:dispatching-parallel-agents`,
one per installed audit, each with:

- The subset of files tagged with at least one of the audit's
  domains (audit-money gets files tagged `money`; audit-tenant
  gets files tagged `tenant`; audit-security gets files tagged
  `secrets` or `auth`; review-contracts gets files tagged
  `api-contract` or `frontend-consumer`).
- The same `<ref>` and `--base`.
- Instruction to produce output in the audit's existing format,
  unchanged.

Rules:

- If a subagent returns no findings because its file subset was
  empty, emit a single line `<audit>: no domain-matching files` in
  place of the sub-report.
- If a subagent errors, log the error and continue — one failure
  does not kill the run. The final summary notes how many audits
  completed.
- If `superpowers:dispatching-parallel-agents` is not available
  (non-Claude-Code agents), fall back to sequential execution with
  a one-line warning.
- Honor `--only=<list>` after dependency resolution: the flag
  narrows what runs now; it does not remove skills from
  `.octopus.yml`.

## Consolidated Report

Output shape:

```
## 🎯 Summary
audit-all: {{BLOCK_COUNT}} block, {{WARN_COUNT}} warn, {{INFO_COUNT}}
info across {{AUDITS_RAN}} audits ({{AUDIT_NAMES}}). Files touched:
{{FILES_TOUCHED}}. Cross-audit hotspots: {{HOTSPOT_COUNT}}.

## 🔥 Cross-audit hotspots

Files flagged by more than one audit — prioritize these first.

{{HOTSPOTS_TABLE}}

## 🔒 audit-security
<audit-security's own output>

## 💰 audit-money
<audit-money's own output>

## 🏢 audit-tenant
<audit-tenant's own output>

## 🔁 review-contracts
<review-contracts's own output>
```

Every sub-report keeps its own summary footer (e.g.
`audit-money: 1 block, 2 warn, 0 info (...)`), so reviewers can
paste a single audit's block into a PR thread for focused
comments.

With `--write-report`: the same content goes to
`docs/reviews/YYYY-MM-DD-audit-all-<slug>.md` with frontmatter
(`ref`, `base`, `audits_ran`, `generated_at`, `summary`).

The header template lives at
`skills/audit-all/templates/report-header.md.tmpl`.

## Errors

- **Unresolvable `ref`** → print the 5 nearest fuzzy matches (tags
  + RMs + branch names from `git for-each-ref`) and exit 1 before
  creating any files.
- **Not a git repo** → abort with "run inside a git repository".
- **No installed audit skills** → abort with
  "audit-all requires at least one installed audit skill".
- **Empty diff** → print "audit-all: no changes to review" and
  exit 0.
- **Unrecognized `--only` value** → abort, list valid values
  (`security,money,tenant,cross-stack`).

## Graceful Degradation

`audit-all` adapts to what's actually installed:

- If `depends_on` resolution (see `setup.sh _resolve_skill_dependencies`)
  skipped a dependency because its SKILL.md is missing, that audit
  is absent from the run. The summary line reports
  `{N} of 4 audits ran; install {list} to enable the rest`.
- If the parallel-dispatch mechanism is unavailable (non-Claude-Code
  agents), execution falls back to sequential with a one-line
  notice. Output shape is identical.
- `--only=<list>` further narrows what runs even when more audits
  are installed.

v1 always exits 0 (guidance, not gate). A future RM can add
`--fail-on=block` for CI.
