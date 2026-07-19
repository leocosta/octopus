---
name: doc-api
model: sonnet
description: >
  On-demand, integrator-facing API contract-fidelity validator and doc
  generator. Validates the whole API surface against an existing OpenAPI spec
  and the repo's own knowledge (ADRs, specs, CONTEXT.md, system maps), reporting
  drift in types, error codes, envelopes, and business fidelity. With --write it
  updates the canonical openapi.yaml and an integrator reference. Not part of
  audit-all; on-demand only. Reuses the audit-grounding source-of-truth protocol.
triggers:
  keywords: ["document api", "api contract", "openapi fidelity", "error catalog", "integrator docs"]
---

# API Contract Fidelity & Documentation Protocol

## Overview

`doc-api` answers the integrator question `audit-contracts` does not: is the
whole published API surface faithful to its OpenAPI spec, are error codes and
messages consistent and documented, and does the documentation an external
consumer reads match the code — enriched with the business context this repo
already records (ADRs, specs, `CONTEXT.md`, system maps).

It runs **on-demand** and is **not** part of `audit-all`. In the default
(validate) mode it is read-only; with `--write` it updates the OpenAPI spec and
an integrator reference behind a confirmation gate.

## When to Engage

Engage when a maintainer wants to validate the external API contract for
fidelity, or regenerate the integrator-facing API documentation.

Do **not** engage for internal API↔frontend drift over a diff (that is
`audit-contracts`), or as an automatic pre-merge gate.

## Invocation

```
/octopus:doc-api [--write] [--only=<checks>] [--stacks=<list>] [--spec=<path>] [--out=<path>] [--base=<ref>]
```

- Default (no `--write`) → **validate**: full-surface, read-only, never writes.
- `--write` → **document**: update spec + integrator doc behind the write gate.
- `--only=<checks>` — subset of `openapi,errors,breaking,grounding`.
- `--stacks=<list>` — subset of detected stack roots (default: all detected).
- `--spec=<path>` — override the OpenAPI spec location (else autodetect).
- `--out=<path>` — override the integrator-doc output (else autodetect/confirm).
- `--base=<ref>` — git ref to diff the spec against for `breaking` (else the
  committed `openapi.yaml` at `HEAD`).

## Pipeline

Follow the Pre-Pass in `skills/_shared/audit-pre-pass.md` first, then:

1. **Discover** — resolve API stack roots per stack; locate the existing OpenAPI
   spec; locate knowledge sources the repo already produces: `docs/adr/`,
   `docs/specs/`, `CONTEXT.md`, system maps (`map-system`), the knowledge base.
2. **Extract** — build the real contract from code: endpoints, request/response
   DTOs and data types, enums, response envelopes, status codes, error responses
   and messages, auth rules. Tag each endpoint with its API version.
3. **Validate** — run the four checks (see `## Checks`) per API version and
   render a severity-tiered report in the shared output format.
4. **Document** (`--write` only) — regenerate the OpenAPI spec and the integrator
   reference behind the write gate.

## API Version Detection

<!-- filled by Task 3 -->

## Checks

<!-- filled by Task 4 -->

## Outputs

<!-- filled by Task 5 -->

## Write Gate

<!-- filled by Task 5 -->

## Composition

<!-- filled by Task 5 -->

## Errors

<!-- filled by Task 5 -->
