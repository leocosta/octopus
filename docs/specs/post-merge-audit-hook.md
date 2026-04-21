# Spec: Post-Merge Audit Hook

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-21 |
| **Author** | <!-- Your name --> |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-029 |

## Problem Statement

Octopus ships four pre-merge audit skills (`money-review`,
`tenant-scope-audit`, `cross-stack-contract`, `security-scan`) plus
the `audit-all` composer, but reviewers and authors have to
remember to run them. In practice they run sporadically — and
the most valuable signals (money-logic drift, missing tenant
filters, cross-stack contract breakage) are precisely the ones
that benefit from being automatic on a hot PR.

## Goals

- A git hook (post-merge or post-commit, TBD in design) that looks
  at the diff of the incoming change, maps touched files +
  keywords to the relevant audits, and surfaces the list as a
  gentle suggestion: "this change touched billing code; consider
  running `/octopus:money-review`".
- Zero-config for the common case: the hook activates for repos
  that have `workflow: true` in `.octopus.yml` and have at least
  one of the audit skills installed.
- Opt-out per repo via a manifest key; opt-out per invocation via
  an env var.
- No execution of audits in the hook itself — just suggestion.
  Audits remain agent-driven.

## Non-Goals

- Running audits automatically in the hook (too slow / too noisy).
- Blocking the merge. The hook is advisory.
- Posting comments on a GitHub PR. Out of scope for this spec;
  could be a follow-up that reuses the same mapping.
- Replacing `/octopus:audit-all` as the pre-merge composer.

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
**Bundle**: N/A — hook lives under the `hooks:` setting, not a
skill.

**Constraints**:
- Pure bash, no external dependencies beyond what the existing
  hooks infrastructure uses.
- Hook must be idempotent and fast (≤ 500 ms on a typical diff).
- Must respect `destructiveGuard` / `hooks:` opt-outs already in
  the manifest schema.

## Testing Strategy

<!-- What tests are needed? Unit, integration, e2e? -->

## Risks

<!-- What could go wrong? What are the unknowns? -->

## Changelog

- **2026-04-21** — Initial draft
