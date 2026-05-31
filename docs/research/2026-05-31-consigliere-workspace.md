# Research: consigliere-workspace

**Date:** 2026-05-31
**Trigger:** Manager pain point — tracking meetings and digesting diverse documents (Slack, Meet transcripts, Jira, Confluence) is done in a fragmented way today. The details that matter (blockers, decisions, system map, political risk) do not live in Jira. Derived from an `interview` concluded the same day that already converged the intent — this research only slices it into roadmap items.

## Context

A sub-initiative of **Cluster 16 — Manager multiplier** (already complete: RM-089…096, RM-098). Where Cluster 16 covers the manager as a multiplier of the **team** (pedagogy, knowledge loop, cross-repo), the **consigliere** covers the manager as a multiplier of **themselves**: a private store of managerial knowledge that digests inputs and keeps living memory of status, blockers, and systems.

The metaphor is literal: a corporate *Chief of Staff* is the executive's "force multiplier" — it filters information, tracks priorities, detects risk and misalignment, connects silos, and keeps the institutional memory. Here the executive served is the manager themselves — a *personal* chief-of-staff. The role is named **`consigliere`** (one word, per Octopus role convention; it connotes a trusted advisor who knows the politics and whispers the risk — exactly the "political risk" field).

It reuses existing guardrails: **`audit-grounding`** (RM-088, shipped v1.69.0) for strict grounding, and the **continuous-learning / review-proposals** pattern for the heuristics loop.

## Analysis

### Data model (the core)

- **Context** = a **perennial** node in a tree of arbitrary depth (product → domain → sub-domain). Each node has its **own materialized state** (not a computed rollup). Example: `commerce` (a product area) → `catalog` (a stable business domain).
- **Project** = a **temporal** entity (start/middle/end), **cross-cutting** — a many-to-many relationship with contexts, possibly spanning workspaces. Example: `checkout-revamp` crosses `payments` and `fulfillment`.
- **Uniform per-node trio** (context or project): `state.md` (materialized) + `journal.md` (append-only, dated) + `playbook.md` (heuristics, optional).
- **Cross-cutting write = fan-out pointer:** the detail (6 fields) lives in the project; the digest propagates a one-line summary into each crossed context's `state.md`, keeping each context self-sufficient for consult without recomputation.

### `manager-workspace` layout (private repo, never committed to a team repo)

```
manager-workspace/
├── README.md                       # operating manual
├── sources/YYYY/MM/<date>-<slug>.md   # raw inputs, immutable (frontmatter: origin, fetched_at) — grounding base
├── contexts/<tree>/                # each node: state.md · journal.md · playbook.md
├── projects/<proj>/                # state.md · journal.md · meta.yml (contexts: [...])
└── people/<person>.md              # per-person heuristics
```

### Digest contract — 6 fields

Status by workstream · Blockers+owner · Decisions · System & area map · Actions+owners · **Political risk** (org/human signals that do not reach Jira: cross-area priority conflict, pending sponsor/decision, expectation misalignment, bus-factor, rework from a reversed decision).

### Capture flow

`/digest-source <text | pdf | JIRA-123 | confluence-url> "natural-language description"` →
immutable snapshot in `sources/` → **infers** context/project from the NL phrase → **confirms** (creates the node on-the-fly if it does not exist) → extracts the 6 grounded fields with source citations → **previews** the writes → **writes** (fan-out). The natural-language phrase IS the routing; ambiguity becomes a question, not a guess.

### Multi-modal — honest feasibility

| Source | Ingestion | Today |
|---|---|---|
| Pasted text | direct | ✅ |
| PDF (local path) | CC reads it natively | ✅ |
| Jira | existing MCP | ✅ |
| Confluence (link) | needs the Atlassian MCP/token | ⚠️ absent → export-PDF fallback |

### Learning loop (what separates "note-taker" from "consigliere")

Bidirectional: the manager **seeds** heuristics they already hold (writes them directly into `playbook.md`) **and** the agent **captures** new ones from digests (proposes → the manager confirms via `playbook-review`). Applied **push** (nudges when reading a fresh input: "owner tends to delay → suggest FUP") and **pull** (on consult).

### Hard constraints

- **Strict grounding:** never assert what is not explicit in the input or in an approved heuristic; when unsure, ask; every claim traces to `sources/`. (Reuses `audit-grounding`.)
- **Privacy:** private, single-user workspace; transcripts and political risk never in a team repo.

### Settled naming

- **Role:** `consigliere`
- **Skills:** `digest-source` · `context-status` · `playbook-review`
- **New bundle:** `consigliere`
- `context-init` was **discarded** — node creation is **on-the-fly** inside `digest-source` (under confirmation).

### Architecture decisions

1. **Where the artifacts are built** → **resolved in [ADR-007](../adr/007-consigliere-artifact-location.md):** role + skills ship **generic in Octopus**, operating on a `manager-workspace` pointed at by config; the *data* always stays in the private workspace.
2. **`consigliere` bundle separate vs merged with `tech-lead`** → **resolved in [ADR-008](../adr/008-consigliere-bundle-separation.md):** **separate** bundle (different audience/data/activation context).
3. **`playbook` format/scope** (per-context vs central) and how the role consults without bloating context → **open**, to be settled in the RM-103 spec.

## Identified Items

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| RM-099 | `consigliere` workspace scaffold + bundle | 🔴 High | medium |
| RM-100 | `digest-source` skill — grounded multi-modal capture with fan-out | 🔴 High | high |
| RM-101 | `consigliere` role — the lens/voice that learns heuristics | 🔴 High | medium |
| RM-102 | `context-status` skill — NL consult over materialized state | 🟡 Medium | low |
| RM-103 | `playbook-review` skill + heuristics learning loop | 🟡 Medium | medium |
| RM-104 | Atlassian MCP integration — Confluence + richer Jira | 🟡 Medium | low |

## Discarded Items

| Title | Reason |
|---|---|
| `context-init` skill (pre-registering a node) | Name collides with `/init` and `doc-subcontext`; node creation becomes **on-the-fly** in `digest-source` under confirmation. Resurfaces as `register-context` only if on-the-fly proves insufficient in practice. |
