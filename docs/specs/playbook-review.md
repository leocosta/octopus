# Spec: playbook-review

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-103 (Cluster 17) |
| **Depends on** | RM-099 (workspace + write-guard), RM-100 (proposes heuristics), RM-101 (the lens that applies them) |
| **Research** | [2026-05-31-consigliere-workspace](../research/2026-05-31-consigliere-workspace.md) |

## Problem Statement

What separates a note-taker from a consigliere is that it **learns**. The manager
seeds heuristics they already hold ("this owner tends to delay → FUP"), and the agent
proposes new ones it notices across digests. `playbook-review` is the skill that
closes that loop: it walks the queue of proposed heuristics, lets the manager promote
the good ones into the right `playbook.md`, and discards the rest. It also helps the
manager seed a heuristic directly.

This spec settles the open architecture decision left from the research: **where the
playbook lives and at what scope**.

## Decision — playbook scope (resolves research open question #3)

Heuristics are **scoped to the node they apply to**, never a single central file:

- **`contexts/<ctx>/playbook.md`** / **`projects/<proj>/playbook.md`** — heuristics
  about that context or project.
- **`people/<person>.md`** — heuristics about a person (delay tendency, bus-factor).

This matches the per-node trio convention (RM-099). There is **no central playbook**;
the `consigliere` lens reads the playbook of the node in scope (plus the relevant
`people/` file) so context stays small. A workspace-wide playbook can be added later
if a real cross-cutting need appears (YAGNI until then).

## Goals

1. **Walk the proposal queue** — `playbook-inbox.md` at the workspace root, where
   `digest-source` appends agent-proposed heuristics (observation + `(src: …)` +
   suggested target + date).
2. For each proposal: show it **grounded**, and let the manager **promote** (write to
   the target's `playbook.md` / `people/<person>.md`), **edit**, or **discard**.
3. **Seed directly** — help the manager add a heuristic they already hold to a chosen
   node, with no queue round-trip.
4. **Strict grounding for agent proposals:** a captured proposal must cite the digest
   line that suggested it; a manager-seeded heuristic is trusted (their own knowledge).
5. Writes stay inside `consigliere.workspace` (RM-099 write-guard).

"Done" = the manager runs `playbook-review`, walks the queue, and the confirmed
heuristics land in the right node `playbook.md` / `people/` file while the inbox is
drained; or seeds a heuristic directly into a chosen node.

## Non-Goals

- Capturing inputs or proposing the heuristics in the first place (that is
  `digest-source`, RM-100, which appends to the inbox).
- Applying heuristics to a reading (that is the `consigliere` role, RM-101, and
  `context-status`, RM-102).
- A central/aggregate playbook or analytics.

## Design

### Overview

A Markdown instruction skill with two modes: **review the queue** (default) and
**seed a heuristic** (`--seed`). It reads `playbook-inbox.md`, walks each proposal
grounded, and writes promoted heuristics to the scoped `playbook.md` / `people/`
file — all inside the write-guard.

### Detailed Design

#### Invocation

```
/octopus:playbook-review            # walk the proposal queue
/octopus:playbook-review --seed     # add a heuristic you already hold, directly
```

#### The queue — `playbook-inbox.md`

`digest-source` appends one block per proposed heuristic:

```
### YYYY-MM-DD — proposed
- observation: <the pattern noticed>
- target: contexts/<ctx> | projects/<proj> | people/<person>
- evidence: (src: sources/…#Ln)
```

The inbox lives at the workspace root, inside `consigliere.workspace`.

#### Step 1 — Resolve workspace + write-guard

Read `consigliere.workspace`; if unset, refuse and point to `consigliere-bootstrap`.
Every write asserts the target is inside the workspace (RM-099 contract).

#### Step 2 — Walk the queue (default mode)

For each proposal in `playbook-inbox.md`, show it with its evidence `(src: …)` and the
suggested target node, then ask the manager to:

- **Promote** — append the heuristic to the target's `playbook.md` (or
  `people/<person>.md`), creating the file from the template if absent;
- **Edit** — adjust the wording or retarget, then promote;
- **Discard** — drop it (optionally noting why).

A processed proposal is removed from the inbox. **Ambiguity about the target → ask.**

#### Step 3 — Seed mode (`--seed`)

The manager states a heuristic they already hold; the skill confirms the target node
and appends it to that node's `playbook.md` / `people/` file directly — no grounding
required (it is the manager's own knowledge), no queue round-trip.

#### Grounding

An **agent-proposed** heuristic must carry its `(src: …)` evidence to be promoted (it
is shown for the manager to verify). A **manager-seeded** heuristic is trusted.
Reuses the `audit-grounding` discipline for the proposed ones.

### Migration / Backward Compatibility

Additive. Adds `playbook-review` to the `consigliere` bundle. The `playbook.md` stub
shipped by RM-099 now gets a defined growth path; no breaking change to it.

## Implementation Plan

1. `skills/playbook-review/SKILL.md` — author the two-mode skill; define the
   `playbook-inbox.md` format; cite the RM-099 write-guard and `audit-grounding`.
2. `bundles/consigliere.yml` — add `playbook-review` to `skills:` (now the full kit).
3. `tests/test_playbook_review.sh` — structural: frontmatter; the inbox queue +
   format; walk/promote/edit/discard; `--seed` direct mode; per-node scope (no central
   playbook); grounding for proposals vs trusted seeds; write-guard.
4. `tests/test_consigliere_bundle.sh` — extend: lists `playbook-review`, member exists.
5. `docs/site/skills/playbook-review.mdx` (+ pt-br, hash in-sync).

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [backend-developer]
**Related ADRs**: [ADR-007, ADR-008]
**Skills needed**: [octopus:scaffold-skill, audit-grounding]
**Bundle**: `consigliere (existing)` — completes the kit (4 skills + 1 role).

**Constraints**:
- Markdown instruction skill; grep-based structural tests; no new deps.
- Per-node playbook scope; no central playbook.
- Writes only inside `consigliere.workspace` (RM-099 write-guard).
- Strict grounding for agent proposals; manager seeds are trusted.
- English-only content; generic examples.

## Testing Strategy

Structural (grep) tests asserting the SKILL documents: the inbox queue + its format,
walk/promote/edit/discard, `--seed` direct mode, per-node scope (no central playbook),
the grounding split (proposals cite evidence; seeds trusted), and the write-guard.
Bundle test extended for the new member.

## Risks

- **Promoting an ungrounded proposal** — mitigated: proposals show their `(src: …)`
  and the manager confirms; seeds are explicitly the manager's own.
- **Heuristic sprawl** — mitigated by per-node scope; each node's playbook stays small.

## Changelog

- **2026-05-31** — Initial draft (RM-103; resolves playbook-scope open question).
