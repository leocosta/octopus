# Design: `doc-api` skill

| Field | Value |
|---|---|
| **Date** | 2026-07-18 |
| **Author** | Leonardo Costa |
| **Status** | Approved |
| **Roadmap** | RM-161 (new) |

## Problem Statement

Octopus can detect contract drift *inside* a monorepo — `audit-contracts`
greps the API diff against the frontend that consumes it, pre-merge. But it
answers an internal question ("does this PR break our own app?"), over a diff,
signal-only. Nobody in the family answers the **integrator** question:

> Is the whole published API surface faithful to its OpenAPI spec, are the
> error codes and messages consistent and documented, and does the
> documentation an external consumer reads actually match the code — enriched
> with the business context this repo already records?

Teams exposing an API to external integrators have no on-demand tool that (a)
validates code ↔ OpenAPI ↔ business knowledge across the entire surface, and
(b) regenerates the spec and an integrator-facing reference when asked. Today
this is manual, drifts silently, and the business rationale for each error code
lives in ADRs and specs that the published docs never reference.

## Goals

- Provide an **on-demand** skill `doc-api` that validates the full API surface
  for contract fidelity and, on request, updates the API documentation.
- **Validate mode (default, read-only):** confront the code against an existing
  OpenAPI spec and against the repo's own knowledge (ADRs, specs, `CONTEXT.md`,
  system maps), and emit a severity-tiered fidelity report.
- **Document mode (`--write`, opt-in):** update the canonical `openapi.yaml`
  (generate it if absent) and emit an integrator-facing markdown reference —
  endpoint reference, error catalog, response envelopes — enriched with business
  context.
- Cover the four fidelity concerns in one skill: OpenAPI conformance, error
  catalog, external breaking changes, and doc↔code business fidelity.
- Support .NET and Node API stacks in the first release, autodetecting the
  existing OpenAPI generator.
- **Detect the API's own versioning scheme** (route-explicit `/v{n}/`, header,
  or query) rather than assuming a single unversioned surface, and scope the
  checks per API version.
- Reuse the existing `_shared/audit-output-format.md` protocol and the
  `audit-grounding` source-of-truth protocol rather than reimplementing them.
  File discovery is full-tree (validate mode is full-surface) — it does **not**
  follow the diff-scoped `_shared/audit-pre-pass.md`.

## Non-Goals

- **Not** part of `audit-all`. `doc-api` is full-surface, reasoning-tier, and can
  write files — it does not belong in the fast mechanical pre-merge composer.
- **Not** driven by a Stop hook. It runs only when the user invokes it.
- Does **not** replace `audit-contracts` (internal API↔frontend drift over a
  diff stays that skill's job).
- Does **not** modify application code — it only ever writes the spec and the
  integrator doc, and only under the `--write` gate.
- Does **not** run contract tests or generate client SDKs.
- No language coverage beyond .NET and Node in the first release (others are
  future work).

## Design

### 1. Identity and positioning

| | |
|---|---|
| Command | `/octopus:doc-api` (family `doc-*`) |
| Bundle | `docs` |
| Model tier | `sonnet` — narrating the error catalog and enriching with business context needs reasoning; a cheap grep pre-pass narrows scope first |
| Invocation | On-demand only; no Stop hook; excluded from `audit-all` |
| Stacks (first release) | .NET (`*.csproj`/`*.sln`, Swashbuckle/NSwag) and Node (`express`/`fastify`/`hono`/`@nestjs/core`) |

### 2. Invocation

```
/octopus:doc-api [--write] [--only=<checks>] [--stacks=<list>] [--spec=<path>] [--out=<path>] [--base=<ref>]
```

- Default (no `--write`) → **validate**: full-surface, read-only, never writes.
- `--write` → **document**: update spec + integrator doc behind a confirmation
  gate (see §6).
- `--only=<checks>` — comma-separated subset of `openapi,errors,breaking,grounding`.
- `--stacks=<list>` — subset of detected stack roots (default: all detected).
- `--spec=<path>` — override OpenAPI spec location (else autodetect, see §4).
- `--out=<path>` — override integrator-doc output (else autodetect/confirm, §5).
- `--base=<ref>` — git ref to diff the spec against for the `breaking` check
  (else the committed `openapi.yaml` at `HEAD` is the baseline, see §4).

### 3. Pipeline

1. **Discover** — resolve API stack roots per stack; locate the existing
   OpenAPI spec; locate the knowledge sources Octopus already produces:
   `docs/adr/`, `docs/specs/`, `CONTEXT.md`, system maps (`map-system` output),
   the knowledge base.
2. **Extract** — from the code, build the real contract: endpoints
   (controllers / route registrations / minimal-API maps), request and response
   DTOs and data types, enums, response envelopes, status codes, error responses
   and messages, auth rules. Each endpoint is tagged with its **API version**
   (see §3a).
3. **Validate** — three-way confront (§4), producing a severity-tiered report in
   the shared output format.
4. **Document** (`--write` only) — regenerate the OpenAPI spec and the
   integrator reference (§5), behind the write gate (§6).

### 3a. API version detection

The skill does **not** assume a single unversioned surface. During Discover it
resolves the API's versioning scheme, in this order:

1. **Route-explicit** (most common) — a version segment in the path, e.g.
   `/v1/orders`, `/api/v2/...`. Detected from route templates
   (`[Route("v{version:apiVersion}/...")]`, `[ApiVersion("2.0")]`,
   `app.MapGroup("/v1")`, `app.use("/v2", ...)`) and from the segment pattern
   `^/?(api/)?v\d+`.
2. **Header-based** — an `api-version` / `Accept` header or a
   `[FromHeader]`/middleware convention.
3. **Query-based** — a `?api-version=` / `?version=` query param.
4. **Unversioned** — none detected; the surface is treated as a single version.

Each extracted endpoint is tagged with its resolved version. When several
versions coexist, the checks in §4 run **per version**: a `/v1` and `/v2`
endpoint are distinct contracts. Findings and the integrator doc are grouped by
version, and `breaking` diffs each version against its own baseline (a removed
`/v1` route is breaking for v1 even if `/v2` adds a replacement). If the scheme
is ambiguous (mixed conventions), the skill reports the detected schemes and
asks the user to confirm which one governs before scoping the checks.

### 4. Checks

Every finding carries a confidence label (`high`/`medium`/`low`) as in the
audit family.

| ID | Check | What it does | Severity |
|---|---|---|---|
| `openapi` | code ↔ spec conformance | Endpoints present in code but missing/stale in spec (and vice-versa); DTO/type mismatches; envelope shape mismatch; status-code mismatch | ⚠ Warn (drift), ℹ Info (spec-only or code-only) |
| `errors` | error catalog | Error codes + messages across the surface: inconsistent codes for the same condition, undocumented codes, messages that leak internals, unstable/renamed codes | ⚠ Warn |
| `breaking` | external breaking change | Surface diverges from the **baseline** spec (the committed `openapi.yaml`) or a git tag, **diffed per API version**: removed/renamed endpoints, removed fields, retyped fields, tightened auth. Adding a new version (e.g. `/v2`) is not breaking; changing an existing one is | 🚫 Block |
| `grounding` | doc↔code business fidelity | Confront the error catalog and endpoint semantics against ADRs/specs/`CONTEXT.md`/system maps, reusing the `audit-grounding` source-of-truth protocol — surfaces `unsupported-domain-fact` and undocumented business rules | ⚠ Warn |

`breaking` baseline resolution: prefer the committed `openapi.yaml` at
`HEAD`; if `--base=<ref>` is given, diff the spec against that ref; if neither a
committed spec nor a base exists, `breaking` reports `no baseline — skipped`
(exit 0 for that check) rather than guessing.

### 5. Outputs

Paths are **autodetected first, defaulted second, and confirmed before any
write** (legacy layouts exist — e.g. `docs/openapi.yml`, `docs/api-reference.md`).

| Artifact | Autodetect order | Default if none found |
|---|---|---|
| Validation report | n/a (always written by the report convention) | `docs/reviews/YYYY-MM-DD-api-<slug>.md` |
| OpenAPI spec | `openapi.yaml`, `openapi.json`, `swagger.json`, `docs/openapi.yml`, generator config output | `openapi.yaml` (repo root) |
| Integrator reference | `docs/api-reference.md`, `docs/api/reference.md` | `docs/api/reference.md` |

The integrator reference contains: endpoint reference, error catalog (code →
condition → message → business rationale sourced from ADR/spec), and response
envelopes. All written artifacts are in **English** (repo convention).

### 6. Write gate (`--write`)

- `--write` never touches application code — only the spec and the integrator
  doc.
- Before writing, the skill prints the resolved output paths (autodetected or
  defaulted) and asks the user to confirm or override each. Legacy paths, when
  detected, are offered as the default so existing layouts are preserved.
- It shows a plan/diff of what will change, then writes only on confirmation.

### 7. Composition and reuse

- Reuses `_shared/audit-output-format.md` (severity headings, confidence labels,
  `--write-report` frontmatter) and the `audit-grounding` source-of-truth
  protocol for the `grounding` check. File discovery is full-tree, not the
  diff-scoped `_shared/audit-pre-pass.md`.
- Registered in the `docs` bundle. Not referenced by `audit-all`.
- Created via `/octopus:scaffold-skill` so frontmatter, `SKILL.md`, optional
  `REFERENCE.md`, and bundle registration are consistent with the family.

### 8. Errors

Shared errors (not a git repo, unrecognized `--only`) behave per the shared
convention. Skill-specific:

- **No API stack detected** → abort with guidance to declare `stacks:` in
  `.octopus.yml` or run from a supported layout.
- **No OpenAPI spec found, validate mode** → `openapi`/`breaking` checks report
  `no spec — skipped`; `errors`/`grounding` still run against the code.
- **No OpenAPI spec found, `--write`** → offer to generate one at the confirmed
  path.

## Testing

Bats-style skill tests mirroring the audit family:

- Discovery resolves .NET and Node stack roots; autodetects existing spec incl.
  legacy `docs/openapi.yml`.
- Version detection: route-explicit `/v1/` and `/api/v2/` are tagged to distinct
  versions; a mixed/ambiguous scheme prompts for confirmation; an unversioned
  surface resolves to a single version.
- Per-version scoping: a removed `/v1` route is 🚫 Block for v1 even when `/v2`
  adds a replacement; adding a brand-new `/v2` alone is not breaking.
- Validate mode is read-only (no files written) and emits the shared report
  format with severity + confidence labels.
- `no spec` path: `openapi`/`breaking` skip cleanly; `errors`/`grounding` run.
- `breaking` with no baseline skips with exit 0; with a baseline flags a removed
  field as 🚫 Block.
- `--write` in dry-run resolves and prints output paths (default and legacy) and
  writes nothing without confirmation.
- Error-catalog check flags an inconsistent code for the same condition.

## Rollout

1. Land the skill, command, bundle registration, and tests (this spec → plan →
   implement).
2. Add RM-161 to `docs/roadmap.md`.
3. Ship in the next release cut from `main`.
