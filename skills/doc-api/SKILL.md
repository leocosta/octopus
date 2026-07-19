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

Do not assume a single unversioned surface. During Discover, resolve the API's
versioning scheme in this order:

1. **Route-explicit** (most common) — a version segment in the path
   (`/v1/orders`, `/api/v2/...`). Detected from route templates and the segment
   pattern `^/?(api/)?v\d+`.
2. **Header** — an `api-version`/`Accept` header or `[FromHeader]`/middleware
   convention.
3. **Query** — a `?api-version=`/`?version=` query param.
4. **Unversioned** — none detected; treat the surface as a single version.

Each endpoint is tagged with its resolved version. When versions coexist the
checks run **per version** — a `/v1` and `/v2` endpoint are distinct contracts;
findings and the integrator doc are grouped by version, and `breaking` diffs
each version against its own baseline. If the scheme is ambiguous (mixed
conventions), report the detected schemes and ask the user to confirm which one
governs before scoping the checks.

## Checks

Findings carry a confidence label (`high`/`medium`/`low`) as in the audit
family, and are scoped per detected API version.

- **`openapi`** — code ↔ spec conformance: endpoints present in code but
  missing/stale in the spec (and vice-versa), DTO/type mismatches, envelope
  shape mismatch, status-code mismatch. ⚠ Warn on drift, ℹ Info for spec-only or
  code-only.
- **`errors`** — error catalog: inconsistent codes for the same condition,
  undocumented codes, messages that leak internals, unstable/renamed codes.
  ⚠ Warn.
- **`breaking`** — external breaking change, diffed **per version** against the
  baseline spec (committed `openapi.yaml`, or `--base` ref): removed/renamed
  endpoints, removed fields, retyped fields, tightened auth. Adding a new version
  (e.g. `/v2`) is not breaking; changing an existing one is. 🚫 Block. If no
  committed spec and no `--base`, report `no baseline — skipped`.
- **`grounding`** — doc↔code business fidelity: confront the error catalog and
  endpoint semantics against ADRs/specs/`CONTEXT.md`/system maps by **reusing the
  `audit-grounding` source-of-truth protocol** (surfaces `unsupported-domain-fact`
  and undocumented business rules). ⚠ Warn. Do not reimplement it here.

## Outputs

Paths are autodetected first, defaulted second, and confirmed before any write
(legacy layouts exist).

| Artifact | Autodetect order | Default |
|---|---|---|
| Validation report | (report convention) | `docs/reviews/YYYY-MM-DD-api-<slug>.md` |
| OpenAPI spec | `openapi.yaml`, `openapi.json`, `swagger.json`, `docs/openapi.yml`, generator config | `openapi.yaml` (repo root) |
| Integrator reference | `docs/api-reference.md`, `docs/api/reference.md` | `docs/api/reference.md` |

The integrator reference contains: endpoint reference, error catalog (code →
condition → message → business rationale sourced from ADR/spec), and response
envelopes, grouped by API version. All written artifacts are in **English**.

## Write Gate

- `--write` never touches application **code** — only the spec and the
  integrator doc.
- Before writing, print the resolved output paths (autodetected or defaulted)
  and ask the user to **confirm** or override each; detected legacy paths are
  offered as the default so existing layouts are preserved.
- Show a plan/diff of the changes, then write only on confirmation.

## Composition

Reuses `skills/_shared/audit-pre-pass.md` (discovery),
`skills/_shared/audit-output-format.md` (severity headings, confidence labels,
report frontmatter), and the `audit-grounding` source-of-truth protocol for the
`grounding` check. Registered in the `docs` bundle. **Not** referenced by
`audit-all` — on-demand, reasoning-tier, and can write.

## Errors

Shared errors (not a git repo, unrecognized `--only`) behave per the shared
convention. Skill-specific:

- **No API stack detected** → abort; advise declaring `stacks:` in `.octopus.yml`
  or running from a supported layout.
- **No OpenAPI spec, validate mode** → `openapi`/`breaking` report
  `no spec — skipped`; `errors`/`grounding` still run against the code.
- **No OpenAPI spec, `--write`** → offer to generate one at the confirmed path.
