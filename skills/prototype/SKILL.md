---
name: prototype
description: >
  Throwaway code to answer one design question before committing to it.
  Bifurcates by question type — logic/state → runnable terminal app;
  UI/look → multiple variants toggleable from one route. No persistence
  by default. The most important deliverable is the answer, not the
  code — capture durably before deleting. Sits in the starter bundle
  as a design-time discipline.
triggers:
  paths: ["**/__prototype__/**", "**/LOGIC.md", "**/UI.md"]
  keywords: ["prototype", "throwaway", "sanity-check"]
---

# Prototyping Protocol

## Overview

A prototype is **disposable code that answers a question**. The
question is what makes a prototype worth running — without one, the
prototype becomes a half-built feature in disguise.

This skill enforces the discipline: identify the question, bifurcate
by question type, build the smallest thing that answers it, capture
the answer durably, and then delete or absorb the code.

Branch details and worked examples live in
[REFERENCE.md](./REFERENCE.md).

## When to Engage

Engage when the user wants to:

- Sanity-check a data model or state machine before committing
- Compare two or more UI directions side-by-side
- Validate that an external API behaves as the docs claim
- Explore "let me play with it" before specifying

Do **not** engage when:

- The user wants the real feature, just smaller — that is `implement`
  with a thin first slice
- The question can be answered by reading code (use `map-system`)
- The question can be answered by reading docs (read the docs)

## Bifurcation Gate

This is the most important step. Misclassifying wastes the prototype.

Ask: **what kind of question?**

| Question type | Branch | Artifact |
|---|---|---|
| State, logic, data model, algorithm | **logic** | Runnable terminal app — see [REFERENCE.md#logic-branch](./REFERENCE.md#the-logic-branch) |
| Visual, layout, interaction feel, copy | **UI** | Single route with multiple variants — see [REFERENCE.md#ui-branch](./REFERENCE.md#the-ui-branch) |

If ambiguous and the user is unavailable, default by the surrounding
code (terminal-shaped repo → logic; web app → UI) and **declare the
assumption** in the artifact.

## The No-Persistence Default

Prototypes do not persist state. Persistence is **what is being
tested**, not assumed. If the prototype writes to a DB or a file,
the question has already shifted — pause and reclassify.

Exception: persistence *is* the question (schema design, migration
shape) → write to a throwaway store (SQLite file in the prototype
directory), never to the real database.

## Capturing the Answer

The step prototypes most often skip and most regret skipping. When
the question is answered, write the answer somewhere durable
**before deleting**:

| Where | When |
|---|---|
| Commit message body | The answer changes how the next commit is written |
| ADR | The answer encodes a hard-to-reverse choice (triple gate from `doc-align`) |
| Issue / PRD | The answer is for an AFK agent to act on later |
| `NOTES.md` next to the code | The answer is local and informal |

If the prototype produced a decisive snippet (state machine, reducer,
schema), `doc-prd` is allowed to embed it — see `doc-prd`'s
"Forbidden Content" exception.

Then delete the prototype, or absorb its non-throwaway parts into the
real code path.

## Anti-Patterns

- Persistence-by-default when persistence is not the question
- "Keep it around in case we want it later" — delete or absorb,
  no third option
- UI variants that share 90% of the markup — radical or do not split
- Logic prototypes without a state-print after each action
- Capturing the answer in chat only — the chat scrolls away
- Misclassifying logic-vs-UI mid-build — restart the bifurcation gate

## Integration with Other Skills

- **`doc-prd`** — embeds prototype-derived snippets when prose would
  lose fidelity
- **`doc-align`** — a prototype is often the artifact that resolves a
  grilling deadlock
- **`implement`** — runs *after* the prototype, taking the answer
  (not the code) as input
- **`doc-lifecycle`** — owns the ADR that captures the answer when
  the triple gate applies

## Reference

- [The logic branch](./REFERENCE.md#the-logic-branch)
- [The UI branch](./REFERENCE.md#the-ui-branch)
- [Where prototypes live in the tree](./REFERENCE.md#where-prototypes-live)
