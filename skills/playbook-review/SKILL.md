---
name: playbook-review
description: >
  Closes the consigliere's learning loop. Walks the queue of heuristics that
  digest-source proposed (playbook-inbox.md) and lets the manager promote the good
  ones into the right per-node playbook — contexts/<ctx>/playbook.md,
  projects/<proj>/playbook.md, or people/<person>.md — edit, or discard. Also seeds a
  heuristic the manager already holds directly (--seed), no queue round-trip. Agent
  proposals must carry their (src: …) evidence to be promoted; manager seeds are
  trusted. Per-node scope, no central playbook. Writes only inside
  consigliere.workspace (the consigliere-bootstrap write-guard). Manual,
  operator-run; completes the consigliere bundle.
triggers:
  keywords: ["playbook review", "review heuristics", "promote heuristic", "seed a heuristic", "my playbook", "what patterns did you notice"]
---

# Playbook Review

## Overview

What makes the consigliere a consigliere and not a note-taker is that it **learns**.
The manager seeds heuristics they already hold ("this owner tends to delay → FUP"),
and `digest-source` proposes new ones it notices across digests. `playbook-review`
closes that loop: it walks the proposal queue, the manager promotes the good ones
into the right playbook, and the rest are discarded. The `consigliere` role
and `context-status` then *apply* those heuristics; this skill
*curates* them.

## Playbook scope (settled here)

Heuristics are **scoped to the node they apply to** — there is **no central
playbook**:

- `contexts/<ctx>/playbook.md` / `projects/<proj>/playbook.md` — about that node.
- `people/<person>.md` — about a person (delay tendency, bus-factor).

This matches the per-node trio from `consigliere-bootstrap`; the lens reads
the playbook of the node in scope plus the relevant `people/` file, so context stays
small.

## When to Engage

Manual, operator-run. Engage to drain the proposal queue after some digests, or to
seed a heuristic the manager already holds. Not auto-invoked.

## Invocation

```
/octopus:playbook-review            # walk the proposal queue
/octopus:playbook-review --seed     # add a heuristic you already hold, directly
```

## The queue — `playbook-inbox.md`

`digest-source` appends one block per proposed heuristic to `playbook-inbox.md` at
the workspace root:

```
### YYYY-MM-DD — proposed
- observation: <the pattern noticed>
- target: contexts/<ctx> | projects/<proj> | people/<person>
- evidence: (src: sources/…#Ln)
```

## Step 1 — Resolve workspace + write-guard

Read `consigliere.workspace`; if unset, refuse and point to `consigliere-bootstrap`.
Every write asserts the target is inside the workspace — the `consigliere-bootstrap`
write-guard. This skill writes (it promotes heuristics), always inside the configured
workspace.

## Step 2 — Walk the queue (default mode)

For each proposal in `playbook-inbox.md`, show it with its `(src: …)` evidence and the
suggested target node, then ask the manager to:

- **Promote** — append the heuristic to the target's `playbook.md` (or
  `people/<person>.md`), creating the file from the template if absent.
- **Edit** — reword or retarget it, then promote.
- **Discard** — drop it (optionally note why).

A processed proposal is removed from the inbox. **Ambiguity about the target → ask**,
never guess.

## Step 3 — Seed mode (`--seed`)

The manager states a heuristic they already hold; the skill confirms the target node
and appends it to that node's `playbook.md` / `people/` file directly — no queue
round-trip.

## Grounding — proposals vs seeds

An **agent-proposed** heuristic must carry its `(src: …)` evidence to be promoted; it
is shown for the manager to verify (reuses `audit-grounding`). A **manager-seeded**
heuristic is **trusted** — it is the manager's own knowledge and needs no evidence.

## Anti-patterns

- Promoting an agent proposal with no evidence — show the `(src: …)` and confirm.
- Writing a heuristic to a central file — scope it to the node (or `people/`).
- Writing anywhere outside `consigliere.workspace`.
- Guessing the target on an ambiguous proposal.

## Related

- Consumes the queue `digest-source` appends to; promotes into the
  `playbook.md` stubs `consigliere-bootstrap` ships.
- Curates the heuristics the `consigliere` role and `context-status` apply.
- Reuses `audit-grounding`.
