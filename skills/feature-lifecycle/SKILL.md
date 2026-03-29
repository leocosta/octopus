---
name: feature-lifecycle
description: >
  Guides the complete documentation lifecycle of a feature —
  from RFC through spec, implementation, ADR capture, and
  knowledge extraction. Determines which documents are needed
  based on scope, risk, and stakeholder count.
---

# Feature Lifecycle Protocol

## Overview

Every feature follows a lifecycle from problem to knowledge. Different phases
produce different documentation artifacts. This protocol helps you decide
which artifacts are needed and when.

## Decision Matrix — Which Documents Are Needed?

Before starting any feature, evaluate these four factors:

| Factor | Low | High |
|---|---|---|
| Teams impacted | 1 team | 2+ teams |
| Uncertainty | Clear solution exists | Multiple viable approaches |
| Reversibility | Easy to undo | Hard/expensive to undo |
| Duration | < 1 week | > 1 week |

Decision rules:

- **All low** → Start with a lightweight Spec (can be inline in PR description)
- **Any high** → Write a detailed Spec (`/octopus:doc-spec`)
- **2+ high** → Write an RFC first (`/octopus:doc-rfc`), then Spec after approval
- **Architectural decision at any point** → Write an ADR (`/octopus:doc-adr`)

## Document Chain

Documents form a chain — each references its predecessors:

```
RFC (if needed) → Spec → Implementation Prompt → Code
                           ↕                       ↕
                          ADRs                  Knowledge
```

- **Spec** links to the RFC that approved it (if one exists)
- **Implementation Prompt** references the Spec it derives from
- **ADRs** reference the Spec section that triggered the decision
- **Knowledge** references the ADR/Spec/PR where a fact was confirmed

## Phase 1: Before Implementation

### RFC — Request for Comments

**Purpose**: Get consensus from stakeholders before investing in detailed design.

**When**: Feature crosses team boundaries, has non-obvious trade-offs, or changes
contracts between systems.

**Location**: `docs/rfcs/YYYY-MM-DD-<slug>.md`
**Create with**: `/octopus:doc-rfc <slug>`

An RFC is NOT a spec. It focuses on:
- What problem we're solving and why now
- Proposed approach at a high level
- Alternatives considered and their trade-offs
- What feedback is needed

The RFC is reviewed and either approved, revised, or rejected. Only after
approval does detailed spec work begin.

### Spec — Feature Specification

**Purpose**: Detailed design that serves as source of truth for implementation.
Also serves as context for AI coding agents.

**When**: Always (complexity varies — from a paragraph for small changes to a
full document for complex features).

**Location**: `docs/specs/<feature-slug>.md`
**Create with**: `/octopus:doc-spec <slug>`

A spec includes:
- Problem statement and goals
- Detailed design (architecture, data model, API contracts)
- Implementation plan (file changes, execution order)
- Context for agents (which knowledge modules, rules, and skills are relevant)
- Migration and backward compatibility plan

### Implementation Prompt

**Purpose**: The spec translated into imperative instructions optimized for an
AI coding agent's consumption.

**When**: The feature is complex enough that handing the raw spec to an agent
would waste tokens on discovery.

**Location**: `docs/specs/<feature-slug>.prompt.md`

This is derived from the spec, not a separate creation. It includes:
- Explicit references to codebase files (line numbers, function names)
- Ordered list of changes to make
- Constraints the agent must follow
- Expected test cases

## Phase 2: During Implementation

### ADR — Architecture Decision Record

**Purpose**: Capture a non-trivial decision made during any phase.

**When**: You choose between alternatives and the reasoning isn't obvious.
If someone might ask "why did we do it this way?" in 6 months, write an ADR.

**Location**: `docs/adrs/NNN-<decision-slug>.md`
**Create with**: `/octopus:doc-adr <slug>`

ADRs are lightweight — context, decision, consequences. See the `adr` skill
for full format and guidelines.

### Implementation Log

**Purpose**: Track deviations from the spec during implementation.

**Where**: In the PR description. Note explicitly:
- What was implemented differently from the spec, and why
- New ADRs created during implementation
- Unexpected findings

## Phase 3: After Implementation

### Knowledge Capture

**Purpose**: Extract lasting insights from the implementation.

**Where**: `knowledge/<domain>/` — following the continuous-learning protocol.

After completing a feature:
1. Identify confirmed facts → `knowledge.md`
2. Identify patterns that need more data → `hypotheses.md`
3. Identify anti-patterns discovered → `knowledge.md` (Anti-Patterns section)

### Spec Update

**Purpose**: Reconcile the spec with reality.

If implementation deviated significantly, update the spec to reflect what was
actually built. Mark deviations with:
```
> **[DEVIATION]** Original plan was X. Implemented Y instead because Z.
> See ADR-NNN for rationale.
```

The spec then serves as documentation, not just a plan.

### Changelog

Update `CHANGELOG.md` with a concise entry describing what changed and why.

## Integration with Other Skills

- **`adr` skill**: Provides the detailed ADR format and writing guidelines
- **`continuous-learning` skill**: Provides the knowledge capture protocol
- **`context-budget` skill**: Helps audit if documentation is adding too much
  to the agent's context window
