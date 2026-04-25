---
name: review-contracts
description: Detect API-vs-frontend contract drift in multi-stack monorepos — endpoints, DTOs, enums, status codes, auth rules, params.
---

---
description: Detect API-vs-frontend contract drift in multi-stack monorepos — endpoints, DTOs, enums, status codes, auth rules, params.
agent: code
---

# /octopus:cross-stack-contract

## Purpose

Scan the current branch (or a provided ref) for contract drift between
an API and its consumers (app / lp / other frontends). Produces a
severity-tiered report (`🚫 Block` / `⚠ Warn` / `ℹ Info`) with
confidence labels, covering seven drift classes.

## Usage

```
/octopus:cross-stack-contract [ref] [--base=main] [--stacks=<list>] [--only=<checks>] [--write-report]
```

## Instructions

Invoke the `cross-stack-contract` skill
(`skills/cross-stack-contract/SKILL.md`). The skill owns the full
workflow: stack discovery, ref/diff resolution, intent extraction,
cross-stack matching, and report rendering.

Do not reinterpret the skill here — dispatch to it.
