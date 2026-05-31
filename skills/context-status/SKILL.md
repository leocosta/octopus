---
name: context-status
description: >
  The read side of the consigliere workspace. Answers a manager's natural-language
  question — "how's payments?", "what's blocked on checkout-revamp?", "who owns the
  fiscal approval?" — from the materialized state, strictly grounded and read-only.
  Infers the target context or project from the question (the same way digest-source
  routes), reads the node's state.md (drilling into journal.md history or a project's
  detail only when needed), and answers concisely with source citations, applying the
  consigliere lens (political risk, approved heuristics). If something is not in the
  recorded state it says "not recorded" and points at digest-source — it never
  invents and it never writes. Manual, operator-run; member of the consigliere bundle.
triggers:
  keywords: ["context status", "how's", "what's blocked", "status of", "consult my workspace", "what do we know about"]
---

# Context Status

## Overview

`digest-source` (RM-100) fills the workspace; `context-status` reads it. Two weeks
after a meeting the manager asks "how's payments? what's blocked?" and wants a
grounded answer assembled from the materialized state — not a re-read of every
transcript. This skill answers natural-language questions over the workspace,
**read-only** and **strictly grounded**. It is the consult half; capture is
`digest-source`, and the heuristics loop is `playbook-review`.

## When to Engage

Manual, operator-run. Engage when the manager asks about the current state of a
context or project — status, blockers, owners, decisions, the system map, or the
political risk. Not auto-invoked.

## Invocation

```
/octopus:context-status "<natural-language question>"
# or a path: /octopus:context-status payments
```

## Step 1 — Resolve workspace (read-only)

Read the `consigliere.workspace` config key. If it is unset, refuse and point the
manager to `/octopus:consigliere-bootstrap`. All reads stay **within** the resolved
workspace — this skill reuses the RM-099 write-guard as a read boundary and **never
writes** anything.

## Step 2 — Interpret the question + route

Map the question to a target — a context path or a project — from the question text
and the existing `contexts/` tree and `projects/*/meta.yml`. When the target is
ambiguous, show what you resolved and let the manager correct it. **Ambiguity → ask,
never guess** (the same routing discipline as `digest-source`).

## Step 3 — Read the materialized state

Read the target node's `state.md` — the six fixed sections (Status by workstream,
Blockers, Decisions, System & area map, Actions, Political risk). A context's
`state.md` carries fan-out pointer lines to the projects it touches; follow a pointer
into a project's `state.md` **only when the question needs the detail**. Read
`journal.md` **only when the question is about history** ("when did X get blocked?").
Read no more than the question requires.

## Step 4 — Answer, grounded, with the consigliere lens

Answer concisely, leading with exactly what was asked (status, blocker, owner, risk).
Every claim carries its provenance — the `state.md` section or the `(src: …)` anchor
behind it. Apply the **`consigliere` role's lens**: surface a relevant **political
risk** or an **approved heuristic** ("owner tends to delay → consider a FUP") **as a
grounded note**, never as invented fact.

**Strict grounding (reuses `audit-grounding`):** answer only from the recorded state,
journal, and sources. If the answer is **not recorded**, say so plainly and suggest
running `/octopus:digest-source` on the relevant input — do **not** guess, and do
**not** fill the gap from outside the workspace.

## Anti-patterns

- Answering beyond the recorded state — say "not recorded" instead of inventing.
- Writing anything — this skill is strictly read-only.
- Guessing the target on an ambiguous question instead of asking.
- Reading every file when the question only needs one `state.md`.

## Related

- Depends on `consigliere-bootstrap` (RM-099, the workspace + write-guard) and the
  state `digest-source` (RM-100) writes.
- Reuses `audit-grounding` (RM-088) and applies the `consigliere` role (RM-101).
- Spec: `docs/specs/context-status.md` (RM-102).
- Sibling: `playbook-review` (RM-103) owns the heuristics loop this skill applies from.
