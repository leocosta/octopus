---
name: doc-api
description: (Octopus) On-demand integrator-facing API contract-fidelity validator and doc generator — code ↔ OpenAPI ↔ business knowledge.
---

# /octopus:doc-api

## Purpose

Validate the whole API surface for contract fidelity against an existing
OpenAPI spec and the repo's knowledge sources, and — with `--write` — update the
canonical `openapi.yaml` and an integrator reference. Produces a severity-tiered
fidelity report (`🚫 Block` / `⚠ Warn` / `ℹ Info`) with confidence labels.

## Usage

```
/octopus:doc-api [--write] [--only=<checks>] [--stacks=<list>] [--spec=<path>] [--out=<path>] [--base=<ref>]
```

## Instructions

Invoke the `doc-api` skill (`skills/doc-api/SKILL.md`). The skill owns the full
workflow: stack + spec + knowledge discovery, API version detection, contract
extraction, the four checks, report rendering, and the `--write` doc generation
behind its confirmation gate.

Do not reinterpret the skill here — dispatch to it.
