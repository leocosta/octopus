# Spec: Consigliere Workspace Scaffold + Bundle

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-099 (Cluster 17) |
| **Research** | [2026-05-31-consigliere-workspace](../research/2026-05-31-consigliere-workspace.md) |

## Problem Statement

The `consigliere` initiative (Cluster 17) gives a manager a private knowledge
workspace that digests diverse inputs into living, grounded memory. Before any of
the behavioral skills can exist (`digest-source` RM-100, the `consigliere` role
RM-101, `context-status` RM-102, `playbook-review` RM-103), there must be a
**well-defined, materializable structure** they all read and write: the directory
contract, the per-node file convention, the `meta.yml` schema, and a registered
bundle to hang the skills on.

This spec defines that foundation — the *shape* of the `manager-workspace` and the
means to create one — without any digestion or query logic.

## Goals

1. Define the **`manager-workspace` directory contract**: `sources/`, `contexts/`,
   `projects/`, `people/`.
2. Define the **per-node trio convention** — `state.md` (materialized current
   state) + `journal.md` (append-only dated log) + `playbook.md` (heuristics,
   optional) — applied uniformly to every context node and project.
3. Define the **`projects/<proj>/meta.yml` schema** (linked contexts, status,
   dates) and the **`sources/` frontmatter schema** (origin, fetched_at, kind).
4. Ship a **`consigliere-bootstrap` skill** that materializes an empty workspace at
   a configured path, with an operating **README**.
5. Register the **`consigliere` bundle** (per ADR-008, separate from `tech-lead`),
   initially containing `consigliere-bootstrap`; later RMs add the remaining skills
   and the role.
6. Define the **workspace-pointer config key** and the **write-guard** that refuses
   to write outside the configured private workspace (per ADR-007).

"Done" = a manager runs the bootstrap skill, points it at a private repo, and gets
a valid, documented, empty workspace skeleton that RM-100+ can build on; the bundle
is discoverable; writing outside the configured path is refused.

## Non-Goals

- `digest-source` ingestion / 6-field extraction / fan-out writes (RM-100)
- the `consigliere` role / heuristics application (RM-101)
- `context-status` natural-language consult (RM-102)
- `playbook-review` learning loop **and the playbook's internal format/scope**
  (RM-103 — research open question #3 stays deferred there)
- Atlassian MCP integration (RM-104)
- Any decision about *content* of digests — this spec is structure only

## Design

### Overview

RM-099 delivers four things:

1. **Templates** under `octopus/templates/consigliere/` — the stub files a workspace
   is built from.
2. **A `consigliere-bootstrap` skill** that copies/instantiates those templates into
   a target private repo and writes the operating README.
3. **A config key** (`consigliere.workspace`) recording the absolute path of the
   private workspace, plus a **workspace-resolution + write-guard** contract that
   every Cluster 17 skill reuses.
4. **The `consigliere` bundle** registered in the bundle manifest.

The *data* never lives in Octopus; only the templates and skill code do (ADR-007).

### Detailed Design

#### Directory contract

```
<manager-workspace>/                 # a private repo; path stored in consigliere.workspace
├── README.md                        # operating manual (generated from template)
├── .gitignore                       # guards against accidental secret commit
├── sources/                         # raw inputs, immutable — grounding base
│   └── YYYY/MM/<date>-<slug>.<ext>
├── contexts/                        # perennial tree, arbitrary depth
│   └── <ctx>/[<subctx>/...]
│       ├── state.md
│       ├── journal.md
│       └── playbook.md              # optional
├── projects/                        # temporal, cross-cutting (M:N to contexts)
│   └── <proj>/
│       ├── meta.yml
│       ├── state.md
│       ├── journal.md
│       └── playbook.md              # optional
└── people/
    └── <person>.md
```

#### Per-node file convention (the trio)

Every context node and every project carries the same three files, so RM-100+ have
one uniform target:

- **`state.md`** — the *materialized* current state. Section headers fixed to the
  6-field contract so consult (RM-102) is deterministic:
  `## Status por frente` · `## Impedimentos` · `## Decisões` ·
  `## Mapa de sistemas/áreas` · `## Ações` · `## Riscos políticos`.
  A leading `<!-- updated: <date> · sources: [...] -->` marker records provenance.
- **`journal.md`** — append-only, newest-last, one dated block per digest:
  `### <date> — <source-slug>` followed by the extracted notes, each line ending
  with a `(src: sources/…#Ln)` citation anchor (grounding hook for RM-100).
- **`playbook.md`** — optional; heuristics scoped to this node. Format/scope is
  **out of scope here** (RM-103). RM-099 only ships an empty stub with a header.

#### `projects/<proj>/meta.yml` schema

```yaml
title: Checkout Revamp             # human label
status: active                     # active | paused | done | abandoned
contexts:                          # the perennial nodes this project crosses (paths)
  - payments
  - fulfillment
started: 2026-05-31                # ISO date
due: 2026-08-15                    # ISO date or null
```

The `contexts` list is what drives the fan-out pointer in RM-100; RM-099 only
defines and validates the schema.

#### `sources/` frontmatter schema

Every file written under `sources/` (by RM-100) must carry:

```yaml
---
origin: <url | JIRA-123 | filename>   # where it came from
kind: meeting | slack | jira | confluence | pdf | text
fetched_at: 2026-05-31                # ISO date
ingested_by: digest-source            # which skill wrote it
---
```

RM-099 defines this schema and a validator; RM-100 produces the files.

#### Config key + workspace resolution + write-guard (ADR-007)

- New config key **`consigliere.workspace`** = absolute path to the private repo.
- **Resolution:** every Cluster 17 skill reads `consigliere.workspace`; if unset, it
  refuses to run and tells the user to run `consigliere-bootstrap`.
- **Write-guard (hard rule):** a skill may write *only* under the resolved
  `consigliere.workspace` path. Before any write it asserts the absolute target is a
  descendant of that path; otherwise it aborts. This is the ADR-007 mitigation
  against leaking managerial data into a team repo.

#### `consigliere-bootstrap` skill

1. Ask for / read the target workspace path; confirm it is a **dedicated private
   repo** (warn if it looks like a code repo — presence of `package.json`,
   `.csproj`, `src/`, etc.).
2. Refuse if the path is inside a known team/work repo unless explicitly overridden.
3. Materialize the directory contract with `.gitkeep`s, write `README.md` from
   template, write a `.gitignore`, and create **one sample context + one sample
   project** as living documentation.
4. Write `consigliere.workspace` into the Octopus config.
5. Print the resulting tree and the "next: `/octopus:digest-source`" hint.

#### Bundle registration (ADR-008)

Register a new bundle `consigliere` in the bundle manifest, separate from
`tech-lead`. Initial membership: `consigliere-bootstrap`. RM-100…103 add
`digest-source`, `context-status`, `playbook-review`, and the `consigliere` role.

### Migration / Backward Compatibility

Net-new. No existing users, no existing data. The bundle is additive; the config key
is new and optional until a Cluster 17 skill is used. Nothing existing changes.

## Implementation Plan

1. **Templates** — add `octopus/templates/consigliere/{README.md, state.md,
   journal.md, playbook.md, meta.yml, gitignore}` stubs encoding the conventions
   above.
2. **Schemas + validators** — a small validator for `meta.yml` and `sources/`
   frontmatter (pure bash + a YAML check), reusable by RM-100.
3. **Config key** — register `consigliere.workspace`; document resolution + the
   write-guard assertion as a shared snippet Cluster 17 skills source.
4. **`consigliere-bootstrap` skill** — `skills/consigliere-bootstrap/SKILL.md`
   implementing the flow above (uses `scaffold-skill` conventions).
5. **Bundle** — register `consigliere` bundle with `consigliere-bootstrap` as its
   first member; ensure no skill ships loose.
6. **Docs** — site entry for the bundle/skill (EN + pt-br), following the public
   docs voice.

## Context for Agents

**Knowledge modules**: [architecture, octopus-bundles]
**Implementing roles**: [backend-developer]
**Related ADRs**: [ADR-005, ADR-007, ADR-008]
**Skills needed**: [octopus:scaffold-skill, adr]
**Bundle**: `consigliere (proposed)` — see Bundle registration; ADR-008 governs the
separation from `tech-lead`.

**Constraints**:
- Octopus skills are Markdown + bash; no new runtime dependencies.
- **Write-guard is non-negotiable** — never write outside `consigliere.workspace`.
- Privacy: bootstrap must warn before scaffolding inside an apparent code/team repo.
- The directory + file conventions are a **contract** RM-100…103 depend on — changes
  after this ships are breaking and need their own note.
- Templates and skill code are public; no managerial data ever ships in Octopus.

## Testing Strategy

- **Bootstrap happy path** — running the skill at an empty path produces the exact
  directory contract, README, sample context + project, and sets the config key.
- **Write-guard** — a write targeting a path outside `consigliere.workspace` aborts.
- **Code-repo warning** — pointing bootstrap at a dir containing `package.json` /
  `src/` triggers the warning/refusal.
- **Schema validators** — a malformed `meta.yml` (missing `contexts`) and a
  `sources/` file missing `origin` are rejected.
- **Bundle discovery** — `consigliere` bundle and its member skill are listed by the
  bundle tooling; nothing ships loose.

## Risks

- **Write-guard gives false confidence** — if a later skill forgets to source the
  guard snippet, the protection lapses. Mitigation: the guard is a single shared
  snippet every Cluster 17 skill `source`s, asserted in tests per skill.
- **Contract churn** — if conventions change after RM-100 builds on them, it breaks
  downstream. Mitigation: lock the contract in this spec; treat changes as breaking.
- **Playbook coupling** — RM-099 ships only an empty `playbook.md` stub; if its
  eventual format (RM-103) needs structure the stub can't hold, the stub changes.
  Acceptable — the stub is intentionally minimal.

## Changelog

- **2026-05-31** — Initial draft (scoped to RM-099; ADR-007/008 incorporated).
