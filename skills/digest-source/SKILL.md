---
name: digest-source
description: >
  Capture skill for the consigliere workspace. Takes a diverse input — pasted text,
  a local PDF/file, a Jira issue, or a Confluence page — plus a one-line
  natural-language description, and turns it into grounded, routed memory: an
  immutable snapshot under sources/, an inferred-then-confirmed route to a context or
  cross-cutting project, a strictly-grounded 6-field extraction (status, blockers,
  decisions, system map, actions, political risk) where every claim cites its source
  line, a preview, and then the writes — a dated journal entry, a rewritten
  materialized state, and fan-out pointers into each context a transversal project
  crosses. Reuses the RM-099 write-guard contract and audit-grounding. Manual,
  operator-run; second member of the consigliere bundle. Confluence depends on the
  Atlassian MCP (RM-104) — falls back to export-PDF/paste until then.
triggers:
  keywords: ["digest", "digest this", "digest source", "capture this meeting", "log this into my workspace", "add to consigliere"]
---

# Digest Source

## Overview

`digest-source` fills the consigliere workspace that `consigliere-bootstrap`
(RM-099) scaffolds. The manager drops an input and describes it in one line; the
skill snapshots it immutably, routes it to the right place in the context/project
tree, extracts the six fields with strict grounding, previews, and writes. It does
**capture** only — querying is `context-status` (RM-102); the heuristics loop is
`playbook-review` (RM-103).

## When to Engage

Manual, operator-run. Engage when the manager has an input in hand — a meeting
transcript, a Slack thread, a Jira issue, a Confluence page — to fold into the
workspace. Not auto-invoked.

## Invocation

```
/octopus:digest-source <source> "natural-language description"
# <source> = pasted text | path/to/file.(pdf|md|txt) | JIRA-123 | https://…confluence…
```

The natural-language description **is** the routing signal — describe the input as
you would to a colleague ("the alignment meeting with the payments team about the new
checkout flow"); the skill translates that into a path in the tree and shows you what
it understood.

## Step 1 — Resolve workspace + write-guard

Read the `consigliere.workspace` config key. If it is unset, **refuse** and point the
manager to `/octopus:consigliere-bootstrap`. Every write below obeys the **canonical
write-guard contract** documented in `consigliere-bootstrap` (RM-099): a write may
land **only** inside the resolved `consigliere.workspace` path — never a team or code
repo. This skill **cites that contract; it does not re-derive it.**

## Step 2 — Ingest → immutable snapshot

Materialize the input as text under `sources/YYYY/MM/<date>-<slug>.<ext>`, with
frontmatter `{origin, kind, fetched_at, ingested_by: digest-source}`. The slug comes
from the description. The snapshot is **immutable — never edited again**; it is the
grounding base every later claim traces back to.

| kind | how it is ingested | available today |
|---|---|---|
| **text** | write the pasted text verbatim | ✅ |
| **pdf** / file | read the local file's text | ✅ |
| **jira** | pull the issue via the Jira MCP | ✅ |
| **confluence** | fetch via the Atlassian MCP; **if it is absent, stop and ask** the manager to export the page as PDF or paste it — do not silently fail (RM-104) | ⚠️ depends |

## Step 3 — Infer route + confirm (on-the-fly creation)

Parse the description against the existing `contexts/` tree and the
`projects/*/meta.yml` files. **Infer** a target — a project and/or a context path, and
the contexts a transversal project crosses — and **show it for confirmation**:

```
🔎 Understood as:
   Project:  checkout-revamp  (from "new checkout flow")
   Contexts: payments, fulfillment  (from its meta.yml)
   Confirm? [Enter] · or correct the path
```

If the target **does not exist**, ask before creating it — materialize the node's
trio (`state.md` / `journal.md` / `playbook.md`) from `templates/consigliere/`.
Routing is **manual-by-confirmation, assisted by inference** — not a flat picklist
and not a silent guess. On **ambiguity, ask; never guess.**

## Step 4 — Grounded 6-field extraction

Extract the digest contract: **Status by workstream · Blockers+owner · Decisions ·
System & area map · Actions+owners · Political risk**. Each extracted line ends
with a `(src: sources/…#Ln)` anchor pointing at the snapshot.

**Strict grounding — reuses `audit-grounding`:** assert **only what is explicit in the
snapshot**. Do not invent a blocker, a decision, or a political risk that was not
stated. Mark an inference as an inference, or ask. When unsure, ask rather than
assert. If it is not in the source, it is not in the digest.

## Step 5 — Preview

Before touching disk, show the exact writes:

- the `journal.md` dated block to be appended;
- the `state.md` diff (the materialized current state);
- the one-line **pointer** destined for each crossed context's `state.md`.

Surface any relevant existing heuristic (`playbook.md` / `people/<person>.md`) as a
**suggestion** ("owner tends to delay → FUP?"), and offer to capture a newly-observed
pattern into the `playbook-review` queue (RM-103). Suggestions are never written as
fact.

## Step 6 — Write (journal + state + fan-out)

On confirmation:

- **append** a `### <date> — <slug>` block to the target's `journal.md` (append-only,
  newest-last);
- **rewrite** the target's materialized `state.md` — carry unresolved items forward,
  update the `<!-- updated: … · sources: [...] -->` marker;
- for a **transversal project**, **fan-out** a single pointer line into each crossed
  context's `state.md`. The detail stays in the project; each context stays
  self-sufficient for `context-status` to answer without recomputation.

## Anti-patterns

- Asserting anything not in the snapshot — strict grounding is the whole point.
- Routing silently without confirmation, or guessing on an ambiguous description.
- Editing a `sources/` snapshot after the fact — it is immutable.
- Writing anywhere outside `consigliere.workspace`.
- Restating the write-guard or grounding rules instead of citing them.

## Related

- Depends on `consigliere-bootstrap` (RM-099) — the workspace contract + write-guard.
- Reuses `audit-grounding` (RM-088) — the strict-grounding discipline.
- Spec: `docs/specs/digest-source.md` (RM-100).
- Next: `context-status` (RM-102) consults the state this skill writes;
  `playbook-review` (RM-103) owns the heuristics loop this skill feeds.
