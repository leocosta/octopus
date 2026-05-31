# Spec: digest-source

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-100 (Cluster 17) |
| **Depends on** | RM-099 (workspace scaffold + write-guard contract) |
| **Research** | [2026-05-31-consigliere-workspace](../research/2026-05-31-consigliere-workspace.md) |

## Problem Statement

The consigliere workspace (RM-099) is an empty contract until something fills it.
`digest-source` is the capture skill: the manager drops a diverse input — a meeting
transcript, a Slack thread, a Jira issue, a Confluence page — with a one-line
natural-language description, and the skill turns it into grounded, routed memory:
an immutable snapshot under `sources/`, a dated journal entry, a rewritten
materialized state, and (for cross-cutting projects) fan-out pointers into the
contexts the work touches.

## Goals

1. Accept a source in any of four shapes — **pasted text, a local file (PDF/md/txt),
   a Jira key, a Confluence URL** — and materialize an **immutable snapshot** under
   `sources/YYYY/MM/` with the RM-099 frontmatter schema.
2. **Route by natural language**: infer the target context/project from the
   manager's description + the existing tree, **confirm** before writing, and create
   a node **on-the-fly** (under confirmation) when it does not exist.
3. Extract the **6-field digest contract** with **strict grounding** — every claim
   carries a `(src: …#Ln)` anchor; nothing is asserted that is not in the snapshot;
   when unsure, ask.
4. Write with **preview-then-commit**: append a dated block to `journal.md`, rewrite
   the materialized `state.md`, and **fan-out a one-line pointer** into each crossed
   context's `state.md` for transversal projects.
5. Honor the **write-guard** (ADR-007): never write outside the configured
   `consigliere.workspace`.

"Done" = a manager runs `/octopus:digest-source <source> "<description>"` and, after
confirming the inferred route and previewing the writes, gets a grounded journal
entry + refreshed state, with every claim traceable to `sources/`.

## Non-Goals

- The natural-language **consult** side ("how's POS?") — that is `context-status`
  (RM-102).
- The **role** lens / autonomous political-risk reading — `consigliere` role (RM-101).
- The heuristics **promotion** loop and the playbook's internal format —
  `playbook-review` (RM-103). `digest-source` may *surface* an existing heuristic and
  *propose* capturing a new one, but it does not own the playbook format.
- A working **Confluence** integration — depends on the Atlassian MCP (RM-104). Until
  then `digest-source` falls back to "export PDF / paste".

## Design

### Overview

`digest-source` is a Markdown instruction skill (the repo model) that walks the agent
through: resolve workspace → ingest to snapshot → infer + confirm route → grounded
extract → preview → write (with fan-out). It **reuses** the RM-099 write-guard
contract and the `audit-grounding` discipline rather than re-deriving them.

### Detailed Design

#### Invocation

```
/octopus:digest-source <source> "natural-language description"
# <source> = pasted text | path/to/file.(pdf|md|txt) | JIRA-123 | https://…confluence…
```

#### Step 1 — Resolve workspace + write-guard

Read `consigliere.workspace`. If unset → refuse, point to `consigliere-bootstrap`.
Every write in later steps asserts its target is inside the resolved workspace (the
RM-099 canonical contract). No write happens outside it.

#### Step 2 — Ingest → immutable snapshot

Materialize the input as text under `sources/YYYY/MM/<date>-<slug>.<ext>` with
frontmatter `{origin, kind, fetched_at, ingested_by: digest-source}`. The slug comes
from the description. Per source kind:

| kind | how | available today |
|---|---|---|
| text | write the pasted text verbatim | ✅ |
| pdf / file | read the local file's text | ✅ |
| jira | pull the issue via the Jira MCP | ✅ |
| confluence | fetch via Atlassian MCP; **if absent, stop and ask** the manager to export the page as PDF or paste it (RM-104) | ⚠️ depends |

The snapshot is **never edited again** — it is the grounding base.

#### Step 3 — Infer route + confirm (on-the-fly creation)

Parse the description against the existing `contexts/` tree and `projects/*/meta.yml`.
Propose a target — a project and/or a context path — and the contexts it crosses, and
**show it for confirmation**. If the target does not exist, ask before creating it
(materializing the node's trio from `templates/consigliere/`). Ambiguity → ask, never
guess. (Routing is manual-by-confirmation, assisted by inference — not a flat list.)

#### Step 4 — Grounded 6-field extraction

Extract **Status por frente · Impedimentos+dono · Decisões · Mapa de sistemas/áreas ·
Ações+owners · Riscos políticos**. Each extracted line ends with `(src: sources/…#Ln)`
pointing at the snapshot. **Strict grounding (reuses `audit-grounding`):** assert only
what is explicit in the snapshot; mark inferences as such or ask; never invent a
blocker or a decision.

#### Step 5 — Preview

Show the exact writes before touching disk: the `journal.md` dated block, the
`state.md` diff (materialized current state), and the one-line pointers destined for
each crossed context's `state.md`. Surface any relevant existing heuristic
(`playbook.md` / `people/`) as a *suggestion* (e.g. "owner tends to delay → FUP?") and
offer to capture a newly-observed pattern into the playbook-review queue (RM-103).

#### Step 6 — Write (journal + state + fan-out)

On confirmation:

- **append** a `### <date> — <slug>` block to the target's `journal.md`;
- **rewrite** the target's `state.md` materialized sections (carry forward unresolved
  items, update the `<!-- updated: … · sources: […] -->` marker);
- for a transversal project, **fan-out** a single pointer line into each crossed
  context's `state.md` (detail stays in the project; the context stays self-sufficient
  for consult).

### Migration / Backward Compatibility

Additive. Adds the `digest-source` skill to the existing `consigliere` bundle; no
change to RM-099 artifacts beyond appending the skill to the bundle's `skills:` list.

## Implementation Plan

1. `skills/digest-source/SKILL.md` — author the six-step skill above; cite the RM-099
   write-guard contract and `audit-grounding`.
2. `bundles/consigliere.yml` — add `digest-source` to `skills:`.
3. `tests/test_digest_source.sh` — structural: SKILL frontmatter; documents the four
   source kinds; the snapshot-first + frontmatter schema; infer→confirm→on-the-fly;
   the `(src:)` grounding anchor + strict-grounding rule; preview-before-write;
   journal-append + state-rewrite + fan-out; write-guard citation; Confluence fallback.
4. `tests/test_consigliere_bundle.sh` — extend: bundle lists `digest-source` and the
   member skill exists.
5. `docs/site/skills/digest-source.mdx` (+ pt-br) — curated docs, hash in-sync.

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [backend-developer]
**Related ADRs**: [ADR-007, ADR-008]
**Skills needed**: [octopus:scaffold-skill, audit-grounding]
**Bundle**: `consigliere (existing)` — adds the second member.

**Constraints**:
- Markdown instruction skill; no new runtime deps; grep-based structural tests.
- **Reuse, do not re-derive:** cite the RM-099 write-guard contract and
  `audit-grounding`; do not restate them.
- Strict grounding is a hard rule: never assert what is not in the snapshot.
- The snapshot under `sources/` is immutable.
- Confluence is a documented fallback until RM-104.

## Testing Strategy

Structural (grep) tests asserting the SKILL documents: the four source kinds, the
snapshot-first immutability + frontmatter schema, infer→confirm→on-the-fly routing,
the `(src:)` grounding anchor, preview-before-write, journal-append + state-rewrite +
fan-out, the write-guard citation, and the Confluence fallback. Bundle test extended
for the new member.

## Risks

- **Hallucinated extraction** — the core risk; mitigated by strict grounding + the
  `(src:)` anchor + `audit-grounding` reuse + preview-before-write.
- **Mis-routing** — mitigated by infer→confirm (never silent) and ask-on-ambiguity.
- **Confluence expectation gap** — mitigated by an explicit fallback message, not a
  silent failure.

## Changelog

- **2026-05-31** — Initial draft (RM-100; depends on RM-099 contract).
