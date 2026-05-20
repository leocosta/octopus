---
name: doc-subcontext
description: >
  Create a scoped CLAUDE.md at a subdirectory of a large monorepo, capturing
  the conventions unique to that area without duplicating the parent
  CLAUDE.md. Reads the parent file first, asks only about the local
  conventions, writes lean (target 50–100 lines), and cross-references the
  parent with "inherits from ../CLAUDE.md" instead of copying. Pairs with
  compress-skill for periodic shrinking and with doc-lifecycle when the
  subcontext encodes a decision worth an ADR. Family doc-*.
---

# Subdirectory CLAUDE.md Authoring

## Overview

Large monorepos that use Octopus inherit a single `CLAUDE.md` at the repo
root. As the repo grows, that file either bloats (every module's
conventions piled together) or rots (root file stays generic while local
conventions live in tribal knowledge). `doc-subcontext` is the discipline
that produces a **per-subdirectory CLAUDE.md** scoped to one module's
conventions, leaving the root file lean.

Claude Code automatically loads the `CLAUDE.md` from the directory where
work is happening, then walks up the tree. The skill exploits this — root
covers what is universally true, each subdirectory covers what is locally
true, nothing is duplicated.

## When to Engage

Engage when:

- The repo is a monorepo with distinct modules (`api/`, `app/`, `lp/`,
  `payments/`, `enrollment/`, etc) and the root `CLAUDE.md` has grown
  past ~150 lines or is becoming a kitchen sink
- A specific module has conventions that do not apply elsewhere (a
  payment-handling area with idempotency rules; a UI area with form
  conventions; a multi-tenant area with scope rules)
- A new contributor working on one module is being slowed down because
  the root `CLAUDE.md` is too broad

Do **not** engage when:

- The repo is not a monorepo and a single `CLAUDE.md` suffices
- The conventions you would write are already in `rules/common/*` —
  promote those instead, do not duplicate
- The "convention" is actually a single decision worth an ADR — use
  `doc-adr` instead

## Protocol

### Step 1 — Read the parent CLAUDE.md

Walk up from the chosen path and read every `CLAUDE.md` between the
target subdirectory and the repo root. List the conventions already
covered. These are off-limits for duplication in the new file.

If no root `CLAUDE.md` exists yet, refuse and route to the root
`CLAUDE.md` generator (`octopus update` / `setup.sh`). A subcontext is
only useful **on top of** a root context.

### Step 2 — Ask the user what is locally unique

One question at a time. Target categories:

- **Domain vocabulary** specific to this module (terms not in
  `CONTEXT.md`'s general glossary)
- **Architecture choices** unique to this module (the api/payments/
  module uses `Result<T>`, the rest of api/ uses exceptions)
- **Test conventions** specific to this module
- **External integrations** this module owns (Stripe, Notion API, etc)
- **Files / paths to avoid** that exist in this module for legacy
  reasons

Skip a category if the user has nothing to say. Do not invent content
to fill it.

### Step 3 — Write the file lean

Target 50–100 lines. Structure:

```markdown
# CLAUDE.md — <module name>

Inherits from `../CLAUDE.md`. This file covers conventions unique to
`<path>` only.

## Local vocabulary

- **Term** — definition (only terms not in the parent glossary)

## Architecture

- (only choices that differ from the parent)

## Tests

- (only conventions that differ from the parent)

## Integrations

- (only integrations this module owns)

## Avoid

- (only files / patterns specific to this module's legacy)
```

Sections with no content get dropped entirely. A file with one section
is fine — it answers one question well.

### Step 4 — Cross-reference, do not duplicate

Every claim in the new file must answer "is this already in the parent
chain?" If yes, the new file should **link** to the parent file (relative
path) or **delete** the claim. Duplication is the failure mode that
turns subcontexts into the same kitchen-sink problem they were meant to
solve.

### Step 5 — Confirm placement and write

Confirm the exact path with the user (`api/payments/CLAUDE.md` vs
`api/CLAUDE.md` — depth matters), then write the file. Do not also
update the parent unless the user asks for that as a separate step.

### Step 6 — Schedule a periodic shrink

Note in the file's footer:

```markdown
<!-- Compress with /octopus:compress-skill when this file exceeds 100 lines. -->
```

This makes the maintenance signal explicit and gives the future reader
a tool to fix the problem instead of growing the file further.

## Anti-Patterns

- Duplicating any section from the parent CLAUDE.md — that defeats the
  whole point
- Writing more than 100 lines on a first pass — split or shrink before
  committing
- Inventing content for empty categories ("just to be thorough")
- Mixing subcontext (conventions) with ADR material (one-time decisions)
- Writing a subcontext for a module that has no unique conventions —
  that file becomes noise and is worse than no file
- Creating subcontexts at every depth (`api/`, `api/payments/`,
  `api/payments/stripe/`) without checking that each adds real
  information — collapse upward when in doubt

## Integration with Other Skills

- **`doc-lifecycle`** — when a subcontext encodes a one-time decision
  (chosen pattern over alternatives), the decision belongs in an ADR
  via `doc-adr`; the subcontext links to the ADR instead of restating
  the rationale
- **`compress-skill`** — sibling family. When a subcontext file
  approaches 100 lines, route to `compress-skill` for a structured
  shrink pass
- **`doc-align`** — when the user is unsure whether a convention is
  truly local or actually a project-wide rule, route to `doc-align`
  first to grill against the existing CONTEXT.md / ADRs
- **`map-system`** — useful precursor for very large monorepos: map
  the module landscape first, then decide which modules deserve a
  subcontext
