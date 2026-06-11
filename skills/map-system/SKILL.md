---
name: map-system
model: sonnet
description: >
  Map a repository at a higher level in its domain vocabulary. Two modes:
  simplified is a one-shot ~30-line textual orientation; complete (default)
  does an exhaustive pass and renders a self-contained themed HTML deck
  (overview, business insights, architecture, API/data contracts). --save (on)
  writes docs/system-map/; --output markdown|html. Manual invocation only.
  Ships in starter.
---

# System Mapping

## Overview

`map-system` answers *"what is this area / this repo, in our own words?"*
at two depths:

- **`simplified`** — a one-shot, ~30-line **textual** orientation map. Its
  value is the **invocation discipline**: sample, do not crawl, one screen.
- **`complete`** (the **default**) — an exhaustive pass that renders a
  **self-contained, themed HTML deck** of the repository: the human-facing
  *"what is this project"* artifact a new engineer is walked through and a
  manager reuses. `onboarding` presents this deck during the ramp.

The two modes are different jobs. `simplified` keeps the micro-skill
discipline; `complete` is allowed — and expected — to crawl.

## When to Engage

Engage **only** when the user explicitly invokes the skill ("map this",
"zoom out", "generate the system map", "I don't know this area"). This
skill is **manual-invocation only** — agents must not engage it
autonomously.

Do not engage when:

- The user already named specific files (read them directly).
- A glossary lookup would answer the question (use `CONTEXT.md`).
- The task is a small, local change (`simplified` is overhead; `complete`
  even more so).

## Invocation — three orthogonal axes

```
map-system                              → DEFAULT: complete + save + html + dark-blue
                                          → docs/system-map/<repo>.html
map-system --mode simplified --no-save  → the quick ~30-line textual map, inline (old default)
map-system --no-save                    → complete picture, inline (not written)
map-system --output markdown            → complete picture saved as a markdown doc
map-system --theme light-jade           → complete deck, light-jade theme
map-system --design-from "<prompt>"     → complete deck, custom theme via frontend-design
```

1. **`--mode simplified | complete`** — content depth. Default **`complete`**.
2. **`--save` / `--no-save`** — write to a file or return inline. Default
   **save on**. `--no-save` returns the content inline as readable markdown,
   regardless of `--output`.
3. **`--output markdown | html`** — saved-file format. Default **`html`**
   (the themed deck via `frontend-design`); `markdown` is the same content as
   a plain document (no theme, no `frontend-design`).

Theme flags (`--theme`, default **`dark-blue`**; `--design-from`) apply to
`--output html` only. Saved files default to `docs/system-map/<repo>.<html|md>`.

## Protocol — `simplified` mode

### Step 1 — Pick the abstraction level

Decide the level *one above* where the question is being asked:

- Question about a function → map the module that owns it.
- Question about a module → map the feature area.
- Question about a feature → map the system boundary.

Never map at the same level as the question — that is just reading the code
with extra steps.

### Step 2 — Identify modules and callers

For the chosen level, list the modules in the area (3–10), their principal
callers, and the data that flows between them — in `CONTEXT.md` vocabulary.

### Step 3 — Output the map

Render as a short list or table, ~30 lines, in the project's domain
language. If `CONTEXT.md` is missing, surface that — the map falls back to
code identifiers.

## Protocol — `complete` mode

The default. Crawls the repository and renders the deck.

### Step 1 — Crawl

Walk the repo exhaustively enough to fill the deck sections below. Read
`CONTEXT.md`, `README`, `docs/adr/*`, the module tree, and (when an API is
present) the route/DTO definitions. This is the one path where the
anti-crawl discipline does **not** apply.

### Step 2 — Assemble the deck sections

Each section degrades gracefully when its source is absent:

1. **Cover** — repo name, one-line purpose, theme branding, generation date.
2. **Project overview & business insights** — what the project does and why,
   in domain vocabulary (sources: `CONTEXT.md`, `README`, the "why" in ADRs).
3. **Architecture & module map** — modules, responsibilities, and how they
   connect, as **inline SVG diagrams** (authored in Mermaid, pre-rendered to
   SVG so the deck needs no runtime).
4. **Contracts** — when an API is detected, the endpoints, DTOs, enums, and
   status codes. Reuse the API-detection heuristics from `audit-contracts`.
5. **Data model** — when a DB is detected, the entities and relationships.
6. **Decisions of record** — the ADRs that shape the codebase, summarized.

Keep it a *presentation*: curated and screen-paced, not a 200-page reference.

### Step 3 — Resolve the theme (html output only)

Mirror the `launch-release` cascade (first match wins):

1. `--design-from="<prompt>"` → synthesize a theme via `frontend-design`.
2. `--theme=<name>` flag.
3. `.octopus.yml` top-level `theme:` key.
4. Default: **`dark-blue`**.

Presets live alongside the `launch-release` themes
(`skills/launch-release/templates/themes/`): **`dark-blue`** (default —
GitHub dark-mode / Primer palette), **`dark-jade`**, **`light-jade`**.

### Step 4 — Render and save

Render the self-contained HTML by filling `templates/deck.html.tmpl` — the
content slots from the crawl, the `THEME_*` variables from the resolved
theme (inline CSS, diagrams as inline SVG — no script runtime, no external
assets). This is
**deterministic** and needs no other skill. When `frontend-design` is
available, use it to **refine** the visual design beyond the base template.
Write to `docs/system-map/<repo>.html` (or `.md` for `--output markdown`),
unless `--no-save`.

### When `frontend-design` is unavailable

`frontend-design` is an **enhancer**, not the renderer:

- **Preset themes** (`--theme <name>`, default `dark-blue`) render the HTML
  deck deterministically from the template — they do **not** need
  `frontend-design`. You get the template's base look; if `frontend-design`
  is present it refines the visuals.
- **`--design-from "<prompt>"`** (custom theme synthesis) is the only path
  that **requires** `frontend-design`. When it is not available, say so and
  fall back to a preset theme — mirroring the `launch-release`
  `--design-from` contract.
- **`--output markdown`** never involves `frontend-design`.

Never fail the run or the ramp over a missing enhancer.

## Anti-Patterns

Scoped to **`simplified` mode** (the discipline that defines it):

- Auto-invocation — the description carries the manual-only flag; respect it.
- Mapping at the same abstraction level as the question.
- Implementation jargon when the project has its own glossary.
- Producing a 200-line map — `simplified` is one screen, ~30 lines.
- Reading every file in the area — `simplified` samples; it does not crawl.

For **`complete` mode**:

- Forking the styling system — reuse `launch-release` themes; do not invent one.
- Emitting HTML with external dependencies — the deck must be self-contained.
- Turning the deck into exhaustive reference docs — it is a *presentation*.

## Integration with Other Skills

- **`frontend-design`** — refines the `complete` HTML deck and synthesizes
  custom themes for `--design-from`; an enhancer, not required for presets.
- **`launch-release`** — the theme schema and presets the deck reuses.
- **`audit-contracts`** — the API-detection heuristics for the contracts section.
- **`onboarding`** — presents the `complete` deck during the ramp.
- **`doc-align`** — often called before it, so grilling starts from shared geography.
- **`doc-lifecycle`** — when the map reveals an undocumented area, the follow-up
  is usually a `CONTEXT.md` update or an ADR.
