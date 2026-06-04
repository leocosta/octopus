---
name: refactor-deepen
description: >
  Find deepening opportunities — shallow modules with interfaces as complex as
  their implementations, micro-modules with no locality, pure functions
  extracted only for testability. Presents a numbered candidate list
  (file/problem/solution/benefits) without proposing interfaces, then grills
  the chosen one via doc-align.
---

# Refactoring for Module Depth

## Overview

The skill hunts for **shallow modules** — abstractions that cost as
much to learn as they save — and proposes consolidations into **deep
modules** where a small interface hides real complexity. It is
read-heavy: most of the work is discovery and presentation; the
refactor itself is gated by user choice and a grilling loop.

A fixed vocabulary (Module / Interface / Implementation / Depth /
Seam / Adapter / Leverage / Locality) is enforced throughout — see
[REFERENCE.md](./REFERENCE.md#canonical-vocabulary).

## When to Engage

Engage when:

- The user asks to improve architecture, find refactor opportunities,
  consolidate tightly-coupled modules, or make code more navigable
- Code review surfaces an interface that looks more complex than the
  implementation behind it
- Onboarding a new module reveals churn through micro-files for a
  single conceptual operation

Do **not** engage when the user wants a specific named refactor
("rename X to Y", "extract this function") — that is implementation.

## Protocol

### Step 1 — Read the glossary and ADRs

Read `CONTEXT.md` and the relevant `docs/adr/*` for the area under
review. Refactors that contradict an ADR must either reopen it (via
`doc-align`) or be rejected.

### Step 2 — Explore (subagent)

Dispatch an Explore subagent over the area looking for shallow-module
signals. The signal catalog lives in
[REFERENCE.md](./REFERENCE.md#shallow-module-signals).

### Step 3 — Apply the Deletion Test

For each candidate, ask: *if I deleted this module, where does the
complexity go?*

- Disappears → it was a pass-through. Delete.
- Reappears in **one** caller → inline. The seam was hypothetical.
- Reappears in **N callers** → the seam was real. Keep, but examine
  depth.

**Rule of thumb:** one adapter = hypothetical seam. Two adapters =
real seam. Adapter count is a high-signal heuristic.

### Step 4 — Present the candidate list

Output a numbered table — **without** proposing interfaces yet:

| # | Files | Problem | Solution | Benefits |
|---|---|---|---|---|

Stop. Do not start refactoring. Wait for the user to pick a
candidate.

### Step 5 — Grill the chosen candidate

Once selected, hand off to `doc-align` for a grilling sub-loop. The
interface is designed *during* the grilling, not proposed upfront.

### Step 6 — ADR if the gate passes

If the refactor encodes a hard-to-reverse decision (removing a public
boundary other teams depend on), `doc-align` produces an ADR.
Otherwise the rationale lives in the commit message.

## Anti-Patterns

- Proposing an interface before the user picks a candidate
- Vocabulary drift (component / service / boundary / helper) when
  Module / Seam / Adapter applies
- Refactoring while behaviour is changing — refactor on green only,
  call out to `test-tdd` if the suite is thin
- Counting lines of code as a quality signal (a 5-line shallow module
  is worse than a 50-line deep one)
- Extracting a pure function "for testability" when the caller is the
  only test
- Raising ADR conflicts that do not warrant reopening the ADR

## Integration with Other Skills

- **`doc-align`** — owns the grilling sub-loop in Step 5
- **`audit-all`** — pre-merge audit runs after the refactor
- **`test-tdd`** — used to bring the test suite up before refactoring
  begins, never during
- **`continuous-learning`** — recurring shallow-module patterns get
  recorded so the same shape is spotted faster next time
- **`doc-lifecycle`** — owns the ADR produced in Step 6

## Reference

- [Canonical vocabulary](./REFERENCE.md#canonical-vocabulary)
- [Shallow-module signals catalog](./REFERENCE.md#shallow-module-signals)
- [Deletion-test worked examples](./REFERENCE.md#deletion-test-examples)
