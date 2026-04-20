---
name: audit-all
description: >
  Run the four quality-audit skills in parallel against one ref —
  security-scan, money-review, tenant-scope-audit, cross-stack-contract.
  Shared file discovery + parallel execution + consolidated report
  with a cross-audit hotspots table.
depends_on:
  - security-scan
  - money-review
  - tenant-scope-audit
  - cross-stack-contract
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
   `skills/money-review/templates/patterns.md`,
   `skills/tenant-scope-audit/templates/patterns.md`). Do not copy
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
  domains (money-review gets files tagged `money`; tenant-scope-audit
  gets files tagged `tenant`; security-scan gets files tagged
  `secrets` or `auth`; cross-stack-contract gets files tagged
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
