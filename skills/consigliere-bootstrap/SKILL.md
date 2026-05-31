---
name: consigliere-bootstrap
description: >
  Scaffold a private manager-workspace — the consigliere's knowledge base — at a
  configured path. Materializes the directory contract (sources/, contexts/,
  projects/, people/), the per-node state/journal/playbook trio, the project
  meta.yml and sources/ frontmatter schemas, and an operating README, then records
  the absolute path in the `consigliere.workspace` config key. Establishes the
  ADR-007 write-guard every Cluster 17 skill obeys: data is written ONLY inside the
  configured private workspace, never into a team/code repo. Warns when the target
  looks like a code repo. Foundation for digest-source (RM-100), the consigliere
  role (RM-101), context-status (RM-102) and playbook-review (RM-103). Manual,
  operator-run; member of the consigliere bundle (ADR-008, separate from tech-lead).
triggers:
  keywords: ["consigliere bootstrap", "set up manager workspace", "scaffold manager-workspace", "init consigliere", "create my consigliere"]
---

# Consigliere Bootstrap

## Overview

The `consigliere` capability digests a manager's diverse inputs into a **private**
knowledge workspace. Before any digesting or querying can happen, that workspace
must exist with a well-defined shape that every other Cluster 17 skill reads and
writes. This skill creates it — and only it. It does no digesting, no querying, no
heuristics; it is the scaffold.

Per **ADR-007**, the artifacts (this skill, the templates) are generic and ship in
Octopus, while **all managerial data lives in the private workspace** whose path is
recorded in the `consigliere.workspace` config key. Per **ADR-008**, this skill
belongs to a **separate `consigliere` bundle**, not `tech-lead`.

## When to Engage

Manual, operator-run. Engage once, when the manager wants to stand up their
workspace, or to re-scaffold a missing piece. Not auto-invoked.

## The workspace contract

```
<manager-workspace>/                       # a PRIVATE repo; path → consigliere.workspace
├── README.md
├── .gitignore
├── sources/YYYY/MM/<date>-<slug>.<ext>    # raw inputs, IMMUTABLE — the grounding base
├── contexts/<ctx>/[<subctx>/...]          # perennial tree, arbitrary depth
│   ├── state.md                           # materialized current state (6 fixed sections)
│   ├── journal.md                         # append-only, dated
│   └── playbook.md                        # heuristics (optional)
├── projects/<proj>/                       # temporal, cross-cutting (M:N to contexts)
│   ├── meta.yml
│   ├── state.md
│   ├── journal.md
│   └── playbook.md
└── people/<person>.md
```

Every node — context or project — carries the same **trio**: `state.md`
(materialized) + `journal.md` (append-only, dated) + `playbook.md` (optional). This
uniformity is the contract RM-100…103 depend on; treat changes to it as breaking.

### `state.md` — the 6-field digest contract

Fixed section headers, so consult (RM-102) is deterministic: **Status por frente ·
Impedimentos · Decisões · Mapa de sistemas/áreas · Ações · Riscos políticos**. A
leading `<!-- updated: … · sources: [...] -->` marker records provenance.

### `journal.md` — append-only with citation anchors

One dated block per digest; every extracted line ends with `(src: sources/…#Ln)` so
each claim traces back to the immutable raw input (the grounding hook for RM-100).

### `projects/<proj>/meta.yml` — the project schema

```yaml
title: POS Activation
status: active            # active | paused | done | abandoned
contexts: [tms, pos]      # perennial context node paths this project crosses
started: 2026-05-31       # ISO date
due: null                 # ISO date or null
```

The `contexts` list drives the fan-out pointer in RM-100.

### `sources/` frontmatter schema

Every file written under `sources/` (by RM-100) carries:

```yaml
---
origin: <url | JIRA-123 | filename>    # where it came from
kind: meeting | slack | jira | confluence | pdf | text
fetched_at: 2026-05-31                 # ISO date
ingested_by: digest-source
---
```

## Config key + write-guard (ADR-007 — non-negotiable)

> **This section is the canonical write-guard contract.** `digest-source` (RM-100),
> `context-status` (RM-102) and `playbook-review` (RM-103) **cite it by reference**
> rather than restating it — they inherit these rules, they do not re-derive them.
> Changing the rules here changes them for the whole bundle.

- **`consigliere.workspace`** stores the absolute path of the private workspace.
- **Resolution:** every Cluster 17 skill reads `consigliere.workspace`; if it is
  unset, the skill refuses to run and tells the user to run this bootstrap.
- **Write-guard:** a Cluster 17 skill may write **only** inside the resolved
  `consigliere.workspace` path. Before any write, assert the absolute target is a
  descendant of that path; otherwise abort. This is the hard rule that keeps
  managerial data out of a team repo. The consigliere **never writes outside the
  configured workspace.**

## Bootstrap flow

1. **Resolve the target path.** Ask the manager for the private workspace path (or
   read `consigliere.workspace` if already set).
2. **Refuse / warn on a code repo.** If the target contains `package.json`, a
   `*.csproj`, `src/`, or other signs it **looks like a code repo**, warn and
   require explicit confirmation before continuing — managerial data must not land
   in a team/code repo.
3. **Materialize the contract** from `templates/consigliere/`: create
   `sources/ contexts/ projects/ people/` (with `.gitkeep`s), write `README.md` and
   `.gitignore`, and seed **one sample context** and **one sample project** as
   living documentation.
4. **Record the config.** Write the absolute path into `consigliere.workspace`.
5. **Confirm and hint.** Print the resulting tree and point the manager to
   `/octopus:digest-source` as the next step.

## Anti-patterns

- Writing any managerial content to the Octopus repo or a team repo — only the
  configured private workspace.
- Scaffolding into an apparent code repo without explicit confirmation.
- Drifting the directory/trio/schema contract after RM-100 builds on it — that is a
  breaking change and needs its own note.

## Related

- ADR-007 (artifact location + write-guard), ADR-008 (separate bundle).
- Spec: `docs/specs/consigliere-workspace-scaffold.md` (RM-099).
- Next: `digest-source` (RM-100), `consigliere` role (RM-101), `context-status`
  (RM-102), `playbook-review` (RM-103).
