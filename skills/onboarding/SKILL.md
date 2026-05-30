---
name: onboarding
description: >
  Ramp a new engineer onto a repo's standards, architecture, and way of
  working — a guided, scoped sequence that composes what already exists
  (CONTEXT.md, ADRs, rules/, the map-system deck, the Definition of Done,
  bundle config) instead of a new content store. Asks the engineer's
  area/stack up front and scopes to it; leads with the manager's optional
  curated seed (docs/onboarding/guide.md) when present. Ephemeral: a
  resumable checklist lives gitignored under .octopus/onboarding/, nothing
  is committed. The durable, manager-facing asset is the map-system deck,
  not an onboarding file. Self-serve via /octopus:onboarding.
triggers:
  keywords: ["onboard", "onboarding", "new to this repo", "getting started", "ramp up", "ramp me up", "first week"]
---

# Onboarding

## Overview

`map-system` maps the *code*; `interview` scopes a *feature*; neither ramps
a *person*. This skill does: it walks a new engineer through the repo's
**standards + architecture + workflow** in a structured order, routing
through the artifacts the team already maintains. It is the human-facing
front door to the encode layer — the way a hire gets to "I know how we work
here" without consuming the manager's first weeks.

The ramp is **scoped** (to a stack/area the engineer names) and
**ephemeral** (a resumable checklist lives gitignored; nothing is
committed). The durable, manager-facing asset a new hire sees is the
**`map-system` deck**, presented at the architecture step — not an
onboarding file.

## When to Engage

Engage when someone is ramping onto a repo — "onboard me", "I'm new here",
"getting started", "ramp me up". Self-serve: the engineer runs
`/octopus:onboarding` themselves.

Do **not** engage to:
- Map a specific area of code mid-task — that's `map-system`.
- Scope a feature — that's `interview`.
- Do HR/people onboarding — this is strictly the engineering ramp.

## Step 0 — Scope and resume

1. **Ask the area/stack up front:** "what area or stack will you start in?"
   Scope the standards and map steps to it — never dump the whole repo.
2. **Resume or start the checklist.** The ramp tracks progress in
   `.octopus/onboarding/<name>.md` (gitignored — `<name>` from
   `git config user.name`, or ask once). If it exists, read it and resume
   from the first unchecked `- [ ]` item. If not, create it with one item
   per ramp step below.
3. **Lead with the manager's seed when present.** If
   `docs/onboarding/guide.md` exists (the manager's optional curated "start
   here" — the ADRs that matter, key modules, a welcome note), **open it
   first** and use it to prioritize the steps below. Without it, the ramp is
   fully auto-derived from live artifacts.

## The ramp

Each step routes to an existing source or skill. Degrade gracefully when a
source is thin — and surface the gap (it is an adoption signal for the
manager).

1. **The domain** — read `CONTEXT.md` (the team's vocabulary). If absent,
   say so: the team should author one (it activates `audit-grounding` and
   `standards`).
2. **The decisions** — the relevant `docs/adr/*`: what was decided and why,
   so the engineer doesn't relitigate settled calls. Scope to the ADRs that
   touch their area (and any the seed flags).
3. **The standards** — the `rules/` that govern their stack/area, including
   `*.local.md` overrides. Point them at the `standards` skill for
   self-serve "what's our standard for X, and why" follow-ups.
4. **The map** — **present the `map-system` deck.** If
   `docs/system-map/<repo>.html` exists, open it; otherwise generate it with
   `map-system` (complete mode), scoped to the engineer's area. When the
   deck / `frontend-design` is unavailable, fall back to
   `map-system --mode simplified` (the textual map).
5. **The way of working** — the PR flow, the **Definition of Done**
   (`definition-of-done`), and which bundles/hooks are active (what the
   engineer's agent will enforce on every commit).
6. **The fleet** — the `workspace:` standard and the other repos they'll
   touch (over 6+ repos this matters). Point at `audit-fleet` (RM-094)
   output when available.

After each step, check its item off in the checklist.

## Anti-Patterns

- **Dumping the whole repo** — the ramp is scoped to the named area; it
  reads live artifacts, it does not paste every file or every ADR.
- **Duplicating `map-system` / `interview`** — onboarding *composes* them;
  it does not re-implement code mapping or feature scoping.
- **Committing the checklist** — it is ephemeral and gitignored. The durable
  asset is the `map-system` deck, not an onboarding progress file.
- **A new content store** — onboarding routes through existing artifacts;
  it never copies their content into a parallel doc.
- **Ignoring the gaps** — a missing `CONTEXT.md` or thin ADRs are surfaced
  as adoption signals, not silently skipped.

## Integration with Other Skills

- **`map-system`** — step 4 presents its complete deck (RM-098); the
  architecture surface of the ramp.
- **`standards`** — the self-serve follow-up for "what's our standard for
  X, and why" after the standards step.
- **`definition-of-done`** — the "way of working" step shows the team DoD.
- **`audit-fleet` (RM-094)** — the fleet step points at its cross-repo
  output when available.
- **`tech-lead` bundle (RM-096)** — the final home; `onboarding` is part of
  the manager kit. Interim home: the `docs` bundle.
