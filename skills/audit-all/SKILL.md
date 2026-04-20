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
