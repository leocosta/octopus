# Spec: context-status

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-102 (Cluster 17) |
| **Depends on** | RM-099 (workspace contract), RM-100 (writes the state it reads) |
| **Research** | [2026-05-31-consigliere-workspace](../research/2026-05-31-consigliere-workspace.md) |

## Problem Statement

`digest-source` (RM-100) fills the workspace; `context-status` is the read side.
Two weeks after a meeting, the manager asks "how's payments? what's blocked?" and
wants a grounded answer from the materialized state — not a re-read of every
transcript. This skill answers natural-language questions over the workspace,
strictly grounded in `state.md` / `journal.md` / `sources/`, and never writes.

## Goals

1. Answer a **natural-language question** ("how's payments?", "what's blocked on
   checkout-revamp?", "who owns the fiscal approval?") over the workspace.
2. **Route by inference + confirm on ambiguity** — map the question to a context
   path or project, the same way `digest-source` does; ask when unclear.
3. Answer from the **materialized state** first (`state.md`), drilling into
   `journal.md` history or a project's detail only when the question needs it.
4. **Strict grounding:** every statement traces to a `state.md`/`journal.md` line or
   a `sources/` anchor; if it is not recorded, say so and point at `digest-source` —
   never invent.
5. **Read-only:** never writes; honors the RM-099 write-guard (read stays inside the
   configured `consigliere.workspace`).

"Done" = the manager asks a question and gets a concise, grounded answer assembled
from the materialized state, with citations, or an explicit "not recorded".

## Non-Goals

- Capturing/ingesting input (that is `digest-source`, RM-100).
- The heuristics promotion loop (that is `playbook-review`, RM-103). `context-status`
  may *apply* an approved heuristic via the `consigliere` lens but does not promote.
- Cross-workspace aggregation or analytics dashboards.
- Any write to the workspace.

## Design

### Overview

A Markdown instruction skill: resolve workspace → interpret question + route →
read the materialized state (and history/detail as needed) → answer grounded with
citations, applying the `consigliere` lens. No writes.

### Detailed Design

#### Invocation

```
/octopus:context-status "<natural-language question>"
# or a path: /octopus:context-status payments
```

#### Step 1 — Resolve workspace (read-only)

Read `consigliere.workspace`; if unset, refuse and point to `consigliere-bootstrap`.
All reads stay within the resolved workspace.

#### Step 2 — Interpret + route

Map the question to a target — a context path or a project — from the question text
and the existing `contexts/` tree + `projects/*/meta.yml`. Show the resolved target
when there is any ambiguity and let the manager correct it. **Ambiguity → ask, never
guess** (mirrors `digest-source` routing).

#### Step 3 — Read the materialized state

Read the target node's `state.md` (the six fixed sections). A context's `state.md`
carries fan-out pointer lines to the projects it touches; follow a pointer into a
project's `state.md` only when the question needs the detail. Read `journal.md` only
when the question is about history ("when did X get blocked?").

#### Step 4 — Answer, grounded, with the consigliere lens

Answer concisely, leading with what the manager asked (status, blocker, owner,
risk). Every claim carries its `(src: …)` / `state.md` provenance. Apply the
`consigliere` role's lens — surface a relevant **political risk** or an approved
heuristic ("owner tends to delay → consider a FUP") **as a grounded note**, never as
invented fact. If the answer is not in the recorded state, say **"not recorded"** and
suggest running `digest-source` — do not guess.

### Migration / Backward Compatibility

Additive. Adds `context-status` to the `consigliere` bundle. No change to existing
artifacts beyond the bundle `skills:` list.

## Implementation Plan

1. `skills/context-status/SKILL.md` — author the four-step read-only consult skill;
   cite the RM-099 write-guard (read scope) and reuse the `digest-source` routing +
   `audit-grounding` grounding.
2. `bundles/consigliere.yml` — add `context-status` to `skills:`.
3. `tests/test_context_status.sh` — structural: frontmatter; read-only / no writes;
   workspace resolution; infer+confirm routing; reads materialized `state.md`;
   journal/detail drill-down only when needed; strict grounding + "not recorded";
   consigliere lens.
4. `tests/test_consigliere_bundle.sh` — extend: lists `context-status`, member exists.
5. `docs/site/skills/context-status.mdx` (+ pt-br, hash in-sync).

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [backend-developer]
**Related ADRs**: [ADR-007, ADR-008]
**Skills needed**: [octopus:scaffold-skill, audit-grounding]
**Bundle**: `consigliere (existing)` — adds the fourth member (3 skills + 1 role).

**Constraints**:
- Markdown instruction skill; grep-based structural tests; no new deps.
- **Read-only** — the skill never writes to the workspace.
- Reuse, do not re-derive: cite the RM-099 write-guard and `audit-grounding`.
- Strict grounding: answer only from recorded state/sources; otherwise "not recorded".
- English-only content; generic examples (no real project vocabulary).

## Testing Strategy

Structural (grep) tests asserting the SKILL documents: read-only/no-writes, workspace
resolution, infer+confirm routing, reading the materialized `state.md`, history/detail
drill-down, strict grounding with the "not recorded" fallback, and the consigliere
lens. Bundle test extended for the new member.

## Risks

- **Answering beyond the record** — the core risk; mitigated by strict grounding +
  the "not recorded" fallback + `audit-grounding` reuse.
- **Mis-routing the question** — mitigated by infer+confirm and ask-on-ambiguity.

## Changelog

- **2026-05-31** — Initial draft (RM-102; depends on RM-099/100).
