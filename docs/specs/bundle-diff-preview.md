# Spec: Bundle Diff Preview

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-21 |
| **Author** | <!-- Your name --> |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-027 |

## Problem Statement

In the Full-mode wizard (`cli/lib/setup-wizard.sh`), users pick
bundles / skills / roles one at a time without any signal of how
much each choice costs — in lines added to the generated config or
in approximate tokens loaded per AI session. The current UX is
"check the box, hope for the best"; users who care about context
budget can only learn the cost after running setup and inspecting
the output.

## Goals

- Show impact per candidate item before confirming a selection:
  - Lines added to the generated CLAUDE.md / agent output file.
  - Approximate token count (using a simple words × 1.3 heuristic).
  - Which rules / roles / MCP servers the item pulls in
    transitively (e.g. a bundle that includes a skill that
    requires a rule file).
- Make cumulative impact visible as selections accumulate — a
  running total at the bottom of the picker.
- Keep the existing flow fast: computing impact must not add
  perceptible latency (target ≤ 200 ms per item on a dev laptop).

## Non-Goals

- Exact token counts per provider. A generic heuristic is enough.
- Impact preview in Quick mode — it already auto-picks bundles
  from persona questions; the user is not choosing per-item there.
- Network calls to any tokenizer. Purely local computation.

## Design

### Overview

<!-- High-level architecture of the solution. -->

### Detailed Design

<!-- Data models, API contracts, component interactions, sequence of operations.
     Be specific enough that an AI agent could implement from this section. -->

### Migration / Backward Compatibility

<!-- How do existing users/systems transition? What breaks? -->

## Implementation Plan

<!-- Ordered list of changes. Each item: what file(s), what changes, dependencies. -->

1. <!-- Step 1 -->
2. <!-- Step 2 -->
3. <!-- Step 3 -->

## Context for Agents

<!-- This section is consumed by AI coding agents to assemble the right context. -->

**Knowledge modules**: <!-- e.g. [domain, architecture] -->
**Implementing roles**: <!-- e.g. [backend-specialist] -->
**Related ADRs**: <!-- e.g. [ADR-001, ADR-005] -->
**Skills needed**: <!-- e.g. [adr, e2e-testing, security-scan] -->
**Bundle**: N/A — CLI UX change, not a new skill.

**Constraints**:
- Pure bash, no external dependencies.
- Must work in the existing `_multiselect` / `_ask_yn` wizard flow
  without a rewrite.
- Impact computation runs offline (no tokenizer, no network).

## Testing Strategy

<!-- What tests are needed? Unit, integration, e2e? -->

## Risks

<!-- What could go wrong? What are the unknowns? -->

## Changelog

- **2026-04-21** — Initial draft
