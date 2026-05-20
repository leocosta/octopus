---
name: map-system
description: >
  Produce a higher-level map of the relevant modules and their callers
  when the agent does not know the area of the code. Output stays in
  the project's domain vocabulary, not implementation jargon. Manual
  invocation only — agents must not map-system on their own initiative.
  Sits in the starter bundle as a transversal utility.
---

# System Mapping

## Overview

A micro-skill. When the agent (or the user) is about to make a
decision in unfamiliar territory, `map-system` produces a one-shot
textual map of the area: which modules matter, who calls them, in
the project's own words.

The skill is intentionally small. Most of its value is the
**invocation discipline**, not the prose.

## When to Engage

Engage **only** when the user explicitly invokes the skill ("zoom
out", "map this", "I don't know this area"). This skill is
**manual-invocation only** — agents must not engage it autonomously.

Do not engage when:

- The user already named specific files (read them directly)
- A glossary lookup would answer the question (use CONTEXT.md)
- The task is a small, local change (the map is overhead)

## Protocol

### Step 1 — Pick the abstraction level

Decide the level *one above* where the question is being asked:

- Question is about a function → map the module that owns it
- Question is about a module → map the feature area
- Question is about a feature → map the system boundary

Never map at the same level as the question — that is just reading
the code with extra steps.

### Step 2 — Identify modules and callers

For the chosen level, list:

- The modules in the area (3–10 is the right ballpark)
- The principal callers of each
- The data that flows between them — in CONTEXT.md vocabulary

### Step 3 — Output the map

Render as a short list or table. Examples in the project's domain
language, not generic terms. No implementation jargon (repository /
service / controller) unless those are the terms CONTEXT.md uses.

If CONTEXT.md is missing, surface that — the map will use code
identifiers as a fallback, but the user should know.

## Anti-Patterns

- Auto-invocation — the skill description carries the manual-only
  flag, and the agent must respect it
- Mapping at the same abstraction level as the question
- Implementation jargon when the project has its own glossary
- Producing a 200-line map — the budget is one screen, ~30 lines
- Reading every file in the area before responding — sample, do not
  exhaustively crawl

## Integration with Other Skills

- **`doc-align`** — often called before `doc-align` so the grilling
  starts from shared geography
- **`refactor-deepen`** — Step 2 (Explore) overlaps; `refactor-deepen`
  does the exhaustive crawl, `map-system` does the sample
- **`doc-lifecycle`** — when the map reveals an undocumented area, the
  follow-up is usually a CONTEXT.md update or an ADR
