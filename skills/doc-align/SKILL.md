---
name: doc-align
description: >
  Stress-test a plan against the project's CONTEXT.md glossary and
  docs/adr/ decisions by grilling the user one question at a time,
  surfacing contradictions between user claims and the actual code,
  and updating CONTEXT.md / ADRs lazily as terms resolve. Pairs with
  doc-prd (publishes the aligned plan) and refactor-deepen (calls
  into doc-align for grilling sub-loops).
---

# Plan Alignment Protocol

## Overview

`doc-align` is the grilling discipline of Octopus. It treats
CONTEXT.md as the **glossary of record** and `docs/adr/` as the ledger
of decisions, then walks the user through the decision tree of a plan
one question at a time. Drift in terminology gets recorded inline;
real architectural trade-offs get an ADR — but only if the **triple
gate** holds.

## When to Engage

Engage when the user wants to:

- Stress-test a plan, design, or RFC against the existing domain model
- Resolve ambiguous terminology before writing code
- Discover hidden disagreements with documented decisions

Do not engage for greenfield brainstorming with no existing docs — use
`superpowers:brainstorming` first, then come back here.

## The Triple Gate for ADRs

An ADR is proposed **only** when all three hold:

1. **Hard-to-reverse** — shapes data, public APIs, or cross-module
   contracts
2. **Surprising without context** — a competent reader asks "why?"
   from the code alone
3. **Real trade-off** — alternatives were viable, and the rejection
   had a recorded reason

Missing any one cancels the ADR. Most decisions fail the gate and stay
as code + commit message. Do not paper `docs/adr/` with preferences.

## Protocol

### Step 1 — Map the domain

Read `CONTEXT.md` (or `CONTEXT-MAP.md` for multi-context repos). If
absent, offer to bootstrap a glossary stub before grilling — grilling
without a glossary surfaces drift but has nowhere to record it.

### Step 2 — Walk the decision tree

Ask **one question at a time**. Each question targets one of: a term
not in CONTEXT.md, a term used differently from CONTEXT.md, a claim
the code might contradict, or a decision treated as obvious when the
trade-off is real. The user's answers reshape the tree — never batch.

### Step 3 — Surface contradictions immediately

When the user's claim diverges from what the code actually says,
**stop** and surface the contradiction before the next question.
Continuing a chain on a false premise poisons the rest of the session.

### Step 4 — Update CONTEXT.md lazily

CONTEXT.md is **glossary only**: term → one-sentence definition in the
project's voice. No implementation details, no spec content, no
scratchpad notes. Cross-references between terms are allowed; long
prose is not. Edit inline as terms resolve, never in a batch at the
end.

### Step 5 — Propose an ADR only when the gate passes

Triple gate passes → draft via `/octopus:doc-adr` with the decision,
rejected alternatives, and the why. Gate fails → resolution lives in
the commit message or PR description.

## Anti-Patterns

- More than one question per turn
- "Just to confirm…" recaps that delay the next real question
- Implementation details, prose, or open issues inside CONTEXT.md
- ADR for a preference, a style choice, or a reversible call
- Continuing the question chain after spotting a contradiction
  without surfacing it
- Re-grilling territory already covered by an existing ADR — read it,
  cite it, move on

## Integration with Other Skills

- **`doc-prd`** — synthesises the aligned plan into a tracker PRD
- **`refactor-deepen`** — uses `doc-align` for its grilling sub-loop
- **`doc-lifecycle`** — owns the ADR / Spec / RFC artifacts produced
  or consulted
- **`superpowers:brainstorming`** — runs *before* `doc-align` when
  the plan does not yet exist
