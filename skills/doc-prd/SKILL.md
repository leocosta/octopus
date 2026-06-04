---
name: doc-prd
description: >
  Synthesise the current conversation into a PRD and publish it to the issue
  tracker without re-interviewing — knowledge is assumed in context from a
  prior brainstorm or doc-align. Forbids file paths and code in the body
  (except prototype snippets that encode a decision). Skips to ready-for-
  agent.
---

# PRD Synthesis Protocol

## Overview

`doc-prd` exists to **bottle** a conversation. The user has already
brainstormed (via `superpowers:brainstorming`) or grilled (via
`doc-align`) or both, and the decisions live in the current context
window. This skill packages those decisions as a PRD, publishes it,
and labels it `ready-for-agent` so an AFK agent can pick it up.

**It does not re-interview.** If the knowledge is not already in
context, refuse and hand back to `doc-align` or
`superpowers:brainstorming`.

## When to Engage

Engage when:

- A brainstorm or grilling session just concluded and decisions are
  fresh in context
- The user says "PRD this", "turn this into a ticket", "write the
  spec from what we just discussed"

Do **not** engage when:

- The conversation is exploratory and decisions are not pinned down —
  grill first
- The user wants a synchronous ADR (use `/octopus:doc-adr`)
- The output is a design doc with rationale (use `/octopus:doc-design`
  or `/octopus:doc-spec`)

## Protocol

### Step 1 — Explore the repo + glossary

Read `CONTEXT.md` and the relevant `docs/adr/*`. The PRD must speak
the project's vocabulary.

### Step 2 — Draft the module sketch

Before writing the PRD body, list modules to be built or modified and
validate with the user. Actively look for **deep modules** — if the
sketch reveals three new shallow files, push back. Ask which modules
deserve test coverage.

This is the **last** interactive step. Everything after is synthesis.

### Step 3 — Write the PRD body

Sections, in order:

1. **Problem** — one paragraph, in domain language
2. **Solution** — one paragraph, no implementation detail
3. **User Stories** — exhaustive, not representative. Every actor /
   path the conversation surfaced gets a story
4. **Implementation Decisions** — the choices already pinned. Cite
   ADRs where they apply
5. **Testing Decisions** — which modules get tests, at what level,
   and why
6. **Out of Scope** — what was explicitly excluded
7. **Further Notes** — open questions the agent should ask before
   starting

### Step 4 — Publish and label

Publish to the project's tracker (Notion / GitHub Issues / etc — the
publication layer is shared with `doc-rfc`). Apply `ready-for-agent`
directly — no re-triage round.

## Forbidden Content

PRDs created by this skill must not contain:

- **File paths** — they rot when the codebase moves
- **Code snippets** — same reason, with one exception

**The exception:** a snippet from a `prototype` run that encodes a
decision more precisely than prose can — state machines, reducer
shapes, schemas. If a prototype produced a 12-line state machine that
captures the design exactly, include it. Cite the prototype.

## Anti-Patterns

- Re-interviewing the user — if knowledge is missing, refuse
- File paths in the PRD body
- Code snippets that are not prototype-derived decisions
- Representative user stories ("e.g. a teacher does X") instead of
  exhaustive ones
- Stopping at `needs-triage` — the PRD is born `ready-for-agent`
- "TBD" markers in Implementation Decisions — if it is TBD, grill
  more before publishing

## Integration with Other Skills

- **`doc-align`** — runs *before* `doc-prd` when decisions are not
  yet pinned
- **`superpowers:brainstorming`** — runs *before* `doc-align` when the
  idea is still being shaped
- **`prototype`** — produces the snippets allowed under the
  exception in "Forbidden Content"
- **`doc-rfc`** / **`doc-spec`** — sibling artifacts. PRD targets the
  tracker for AFK agents; RFC/Spec target `docs/` for design review
- **`triage-issues`** — does not re-triage the published PRD
