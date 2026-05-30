# Spec: onboarding-skill

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-30 |
| **Author** | Leonardo |
| **Status** | Approved (interview-refined 2026-05-30) |
| **RFC** | N/A |
| **Roadmap** | RM-090 (Cluster 16) — depends on RM-098 (`map-system` complete deck) |

## Problem Statement

When a new engineer joins, there is no flow that ramps them onto **the team's standards, conventions, ADRs, and way of working**. `map-system` maps the *code*; `interview` scopes a *feature*; neither onboards a person. Over 6+ repos this is recurring, and today it consumes the manager's first weeks with each hire — and the result varies per hire. An onboarding skill makes the ramp self-serve and consistent.

## Goals

- A skill `onboarding` that guides a new engineer through a repo's **standards + architecture + workflow** in a structured order, composing what already exists.
- **Presents the `map-system` complete deck** (RM-098) as the architecture step — a themed, self-contained repo overview, not a wall of text.
- Auto-derives the ramp from live artifacts, and **prioritizes an optional manager-curated seed** (`docs/onboarding/guide.md`) when present.
- Scopes to a stack/area the engineer names up front; **ephemeral** by design — a resumable checklist lives gitignored under `.octopus/onboarding/`, nothing is committed.
- Invokable by the engineer themselves (`/octopus:onboarding`); registered in `tech-lead` (RM-096), interim `docs`.

## Non-Goals

- Not a code-mapping tool (delegates to `map-system` for that).
- Not feature scoping (that's `interview`).
- Not HR/people onboarding — strictly the *engineering* ramp.
- Not a new content store — it routes through existing artifacts (`CONTEXT.md`, ADRs, `rules/`, the `map-system` deck, bundle config, `README`).
- Not a manager-visible progress tracker — onboarding is ephemeral; the durable, manager-facing asset is the committed `map-system` deck, not an onboarding file.

## Design

### Overview

An orchestrator skill that runs a new engineer through a defined ramp sequence, calling existing capabilities and artifacts in order, presenting the `map-system` deck for the architecture step, and keeping a gitignored, resumable checklist so the ramp survives across sessions without polluting the repo. It is the human-facing front door to the encode layer.

### Detailed Design

**Up-front question:** "what area/stack will you start in?" — scopes the standards and map steps to it rather than dumping the whole repo.

**Seed precedence.** If `docs/onboarding/guide.md` (the manager's optional curated "start here" — the 5 ADRs that matter, key modules, a welcome note) exists, the ramp **leads with it** and uses it to prioritize the auto-derived steps. Without it, the ramp is fully auto-derived from live artifacts. The manager curates the seed **once per repo** (optional) — high signal without becoming the per-hire bottleneck.

**Ramp sequence (each step routes to an existing source/skill):**

1. **The domain** — read `CONTEXT.md` (vocabulary). If absent, flag it (the team should author one — adoption signal).
2. **The decisions** — the relevant `docs/adr/*`: what was decided and why, so the engineer doesn't relitigate.
3. **The standards** — the `rules/` that govern their stack/area (incl. `*.local.md` overrides); offer `standards` (RM-092) for follow-up questions.
4. **The map** — **present the `map-system` complete deck.** If `docs/system-map/<repo>.html` exists, open it; otherwise generate it (`map-system`, complete mode) scoped to the engineer's area.
5. **The way of working** — PR flow + Definition of Done (RM-091) + which bundles/hooks are active (what their agent will enforce).
6. **The fleet** — the workspace standard and the other repos they'll touch (points to `audit-fleet`, RM-094, output if available).

**Ephemeral, resumable checklist.** The ramp writes a checklist to `.octopus/onboarding/<name>.md` (gitignored), with `- [ ]` items per step. Re-invoking reads it and resumes from the first unchecked item. `<name>` derives from `git config user.name` (or is asked once). Nothing is committed; the engineer's progress is local.

### Migration / Backward Compatibility

Additive skill. Degrades gracefully when `CONTEXT.md`/ADRs are thin — it surfaces the gaps as part of the ramp (and as a nudge to the manager to fill them). When the `map-system` deck or `frontend-design` is unavailable, step 4 falls back to the textual map (`map-system --mode simplified`).

## Implementation Plan

1. `skills/onboarding/SKILL.md` — frontmatter (capability + cues; `triggers.keywords`: "onboard", "new to this repo", "getting started", "ramp up"), Overview, the up-front area question, the seed-precedence rule, the six-step ramp protocol (step 4 presents the `map-system` deck), the ephemeral-checklist mechanics, Anti-Patterns (don't dump the whole repo; don't duplicate `map-system`/`interview`; don't commit the checklist), Integration (`map-system`, `standards`, DoD, `audit-fleet`).
2. `.gitignore` — add `.octopus/onboarding/` (the ephemeral checklist location).
3. Register in `bundles/docs.yml` (interim); `bundles/tech-lead.yml` (RM-096) is the final home.
4. `tests/test_onboarding.sh` — grep-structural: skill exists, declares the ramp steps, asks the area question, presents the `map-system` deck, honors the optional `docs/onboarding/guide.md` seed, keeps the checklist under `.octopus/onboarding/`, references DoD + standards + fleet, registered in the docs bundle.
5. Docs site: `docs/site/skills/onboarding.mdx` + pt-br pair; skills index rows (EN + pt-br).

## Context for Agents

**Knowledge modules**: [documentation]
**Implementing roles**: [tech-writer]
**Related ADRs**: N/A
**Skills needed**: [scaffold-skill, map-system]
**Bundle**: `docs (existing)` interim; `tech-lead (proposed, RM-096)` final
**Constraints**:
- Read-only orchestration except the gitignored checklist; composes existing skills, adds no parallel content store.
- Ephemeral: nothing committed; the manager-facing durable asset is the `map-system` deck.
- Scopes to a named area; never dumps the whole repo.
- Markdown skill + grep-based bash test; pt-br site pair with source_hash.

## Testing Strategy

- Structural grep test (above).
- Scenario checks: (1) invoking with an area returns a scoped ramp (ADRs + rules for that area + the `map-system` deck); (2) a repo with `docs/onboarding/guide.md` leads with the seed; (3) a repo with no `CONTEXT.md` yields a ramp that flags the gap; (4) re-invoking resumes from the first unchecked checklist item.

## Risks

- **Overlap with `map-system`:** mitigated — onboarding *composes* it (step 4 presents the deck), owns the standards/workflow ramp it doesn't cover.
- **Staleness of the ramp:** mitigated — it reads live artifacts each run, so it tracks the repo's current state.
- **Seed rots:** the manager's `docs/onboarding/guide.md` drifts. Mitigated — it is optional and only *prioritizes*; the auto-derived steps still read live artifacts.

## Changelog

- **2026-05-30** — Initial draft.
- **2026-05-30** — Interview-refined: ephemeral ramp (gitignored resumable checklist under `.octopus/onboarding/`, nothing committed); optional manager seed `docs/onboarding/guide.md` with precedence; step 4 presents the `map-system` complete deck (RM-098 dependency).
