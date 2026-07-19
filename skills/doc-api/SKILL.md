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

<!-- filled by Task 2 -->

## Pipeline

<!-- filled by Task 2 -->

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
