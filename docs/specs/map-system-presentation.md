# Spec: map-system-presentation (`map-system` complete mode)

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-30 |
| **Author** | Leonardo |
| **Status** | Draft (interview-refined 2026-05-30) |
| **RFC** | N/A |
| **Roadmap** | RM-098 (Cluster 16) — RM-090 (`onboarding`) depends on it |

## Problem Statement

`map-system` today is a deliberately tiny skill: a one-shot ~30-line **textual** orientation map, manual-invocation only, explicitly anti-exhaustive ("sample, do not crawl"). That is the right tool for *"I don't know this area, zoom me out"*. It is the **wrong** tool for the other recurring need a manager has across 6+ repos: a **shareable, self-contained presentation of the whole repository** — the overview, the business insights, the architecture diagrams, the API contracts — that a new engineer can be walked through and that the manager can reuse. There is no Octopus capability that produces that artifact; today it is hand-built per repo.

## Goals

- Evolve `map-system` with a **`complete` mode** that renders a **self-contained, themed HTML presentation** of the repository: project overview, business insights, architecture/module diagrams, and API/data contracts when present.
- Add orthogonal **`--save`** (persist to file vs inline) and **`--output markdown|html`** (saved format, default `html`) controls.
- Reuse the existing theme machinery (`launch-release` theme schema + presets + `--design-from` synthesis via `frontend-design`) instead of inventing a new styling system.
- Make the **deck the new default** of `map-system` (`complete` + save + `html` + `dark-blue`), with the quick textual map preserved as `--mode simplified --no-save`.
- Produce a durable, committed asset (`docs/system-map/<repo>.html`) that `onboarding` (RM-090) presents during the ramp and the manager reuses standalone.

## Non-Goals

- Not a replacement for the simplified map — `complete` mode is additive, not the new default.
- Not a live/served dashboard — it emits a static self-contained HTML file (no build step, no server).
- Not a docs generator for every module — it is a *presentation* (curated, screen-paced), not exhaustive API reference docs.
- Not a new theme system — it consumes `launch-release` themes; it does not fork them.

## Design

### Overview

`map-system` gains three orthogonal axes — `--mode`, `--save`, `--output` — and a **new default**: a bare `map-system` now produces the full, saved, themed HTML deck (`complete` + save + `html` + theme `dark-blue`). The quick textual orientation becomes **opt-in** via `--mode simplified`. The themed, self-contained deck is the `complete` + `html` combination, rendered deterministically from a template, styled by a `launch-release` theme, and refined by `frontend-design` when it is available.

```
map-system                              → DEFAULT: complete + save + html + dark-blue → docs/system-map/<repo>.html
map-system --mode simplified --no-save  → the quick ~30-line textual map, inline (the old default; opt-in now)
map-system --no-save                    → full picture, inline (not written to a file)
map-system --output markdown            → full picture saved as a markdown doc
map-system --theme light-jade           → full deck, light-jade theme
map-system --design-from "…"            → full deck, custom theme via frontend-design
```

### Detailed Design

**The three axes.**

1. **`--mode simplified | complete`** (default **`complete`**) — the **content depth**. `simplified` is today's micro orientation: sample, do not crawl, ~one screen. `complete` does the exhaustive pass and renders every deck section below. The anti-patterns that forbid exhaustive crawling and 200-line output are scoped to **`simplified` mode only**; `complete` mode is *allowed and expected* to crawl.
2. **`--save` / `--no-save`** (default **save on**) — whether the result is **written to a file** or returned **inline** in the response. `--no-save` returns the content inline as readable text (markdown), regardless of `--output`.
3. **`--output markdown | html`** (default **`html`**) — the **format of the saved file**. `html` produces the self-contained themed deck (template + preset theme, deterministic; refined by `frontend-design` when available); `markdown` produces the same content as a plain markdown document (no theme, no `frontend-design`).

Theme flags (`--theme`, default **`dark-blue`**; `--design-from`) apply to `--output html` only. Default saved path is `docs/system-map/<repo>.<html|md>`.

**Deck content (the sections rendered).** Each section degrades gracefully when its source is absent:

1. **Cover** — repo name, one-line purpose, theme branding.
2. **Project overview & business insights** — what the project does and why, in domain vocabulary. Sources: `CONTEXT.md`, `README`, the "why" recorded in `docs/adr/*`.
3. **Architecture & module map** — the modules, their responsibilities, and how they connect, rendered as **inline SVG diagrams** (authored in Mermaid, pre-rendered to SVG so the deck carries no script runtime). The `--save` crawl produces the structure the default mode only samples.
4. **Contracts (when an API is detected)** — endpoints, DTOs, enums, status codes. Reuses the API-detection heuristics from `review-contracts`.
5. **Data model (when a DB is detected)** — entities and relationships.
6. **Decisions of record** — the ADRs that shape the codebase, summarized.

The deck is a *presentation*: curated and screen-paced (slide/section style), not a 200-page reference.

**Theming — reuse `launch-release`.** The deck is styled by a theme YAML following the `launch-release` theme schema (`palette` / `typography` / `layout` / `voice` / `brand`). Theme resolution mirrors `launch-release`:
1. `--design-from="<prompt>"` → synthesize a new theme via `frontend-design` (same contract as `launch-release`).
2. `--theme=<name>` flag.
3. `.octopus.yml` top-level `theme:` key.
4. Default: **`dark-blue`**.

Three presets ship: **`dark-blue`** (the default — the GitHub dark-mode / Primer palette: background `#0d1117`, accent `#58a6ff`, text `#c9d1d9`; our own name, not a GitHub Pages theme), **`dark-jade`** (the existing `jade` palette), and **`light-jade`** (a light-background variant). They live alongside the other presets so both skills share them.

**Rendering.** The self-contained HTML is produced **deterministically** by filling `templates/deck.html.tmpl` — the content slots from the crawl, the `THEME_*` variables from the resolved theme (inline CSS, diagrams as inline SVG, no script runtime, no external dependencies). `frontend-design` is an **enhancer**: when available it refines the visual design beyond the base template, and it is **required only for `--design-from`** (custom theme synthesis). Preset themes render without it. Output is a single `.html` file — openable directly and presentable.

**Output.** Saved files default to `docs/system-map/<repo>.<html|md>` (committed — a reusable, version-controlled asset). The extension follows `--output`.

### Migration / Backward Compatibility

**This changes the default behaviour of `map-system`** — it is not purely additive. A bare `map-system` previously returned the quick inline textual map; now it generates and **saves** the full themed HTML deck. Callers who want the old behaviour use `--mode simplified --no-save`. Because the skill is **manual-invocation only** (agents must not invoke it autonomously), the blast radius is bounded to explicit human/skill calls — but the change must be called out in the changelog and the docs.

The new default does **not** require `frontend-design`: preset themes (default `dark-blue`) render the HTML deck deterministically from the template. `frontend-design` only refines the visuals when present, and is required solely for `--design-from` (custom theme synthesis) — which falls back to a preset when it is absent. The starter-bundle membership is unchanged.

## Implementation Plan

1. `skills/map-system/SKILL.md` — add the three axes (`--mode simplified|complete`, `--save`, `--output markdown|html`), the deck-section spec, the theme-resolution cascade, the `frontend-design` composition, and the exhaustive-crawl allowance for `complete`. Scope the existing anti-patterns (no crawl, ~30 lines) to **`simplified` mode**.
2. Theme presets — `dark-blue.yml` (default; Primer palette), `dark-jade.yml`, and `light-jade.yml` in the shared `launch-release` themes directory (`skills/launch-release/templates/themes/`), following the theme schema. `dark-jade` mirrors the current `jade` palette.
3. Deck template — `skills/map-system/templates/deck.html.tmpl` (self-contained skeleton: cover + section slots + an inline-SVG diagram slot), which `frontend-design` fills and themes. Models the `launch-release` `html/*.tmpl` approach.
4. `tests/test_map_system_save.sh` — grep-structural: skill declares `--mode simplified|complete` (default `complete`), `--save`/`--no-save`, `--output markdown|html` (default html), default theme `dark-blue`; references `frontend-design` and the `launch-release` theme system; `simplified`-mode anti-crawl discipline preserved; `dark-blue`/`dark-jade`/`light-jade` presets exist; saved output defaults to `docs/system-map/`.
5. **ADR** — "map-system gains a heavy `--save` deck mode that reuses the launch-release theme machinery" (two-mode skill identity + cross-skill theme reuse; a real alternative — a separate `system-presentation` skill — was considered and rejected to keep one home for system mapping).
6. Docs site: `docs/site/skills/map-system.mdx` (the skill graduates from index-only to a detail page) + pt-br pair; update the skills index rows (EN + pt-br) to note the two modes.
7. Roadmap: add RM-098 to Cluster 16; note RM-090 depends on it.

## Context for Agents

**Knowledge modules**: [documentation]
**Implementing roles**: [tech-writer, frontend-developer]
**Related ADRs**: [proposed: map-system-save-deck-and-theme-reuse]
**Skills needed**: [frontend-design, launch-release (theme schema), review-contracts (API detection)]
**Bundle**: `starter` (map-system already ships there) — the new modes ride the same skill; no new bundle entry.
**Constraints**:
- The deck (`complete`) is the new default; `simplified` mode keeps the old micro behaviour and is the only mode with the anti-crawl discipline. `--save`/`--no-save` and `--output` are orthogonal controls (persist? format?).
- Self-contained HTML output — no build step, no external assets.
- Reuse `launch-release` themes; do not fork the styling system.
- pt-br site pair with source_hash, per site convention.

## Testing Strategy

- Structural grep test (above).
- Scenario checks: (1) `map-system` with no flag still returns a short textual map; (2) `map-system --mode complete --save` on a repo with an API writes an HTML deck containing the contracts section to `docs/system-map/`; (3) `--output markdown` writes the same content as a markdown doc; (4) `--theme light-jade` resolves the preset; (5) missing `frontend-design` degrades (markdown or inline) plus a note, without failing.

## Risks

- **Breaking default change:** a bare `map-system` now crawls and writes a committed file — surprising to anyone expecting the old inline micro map. Mitigated by: manual-invocation-only (bounded blast radius), `--mode simplified --no-save` preserving the old behaviour, and an explicit changelog/docs note. (It does **not** add a hard `frontend-design` dependency — preset HTML renders without it.)
- **Scope creep / philosophy drift:** the micro-skill becoming a heavyweight generator. Mitigated by the strict mode split — `simplified` keeps its discipline; only `complete` is heavy.
- **Stale decks:** a committed HTML deck drifts from the code. Mitigated — the deck is regenerated on demand (cheap to re-run); it is a snapshot, dated on the cover.
- **`frontend-design` unavailable:** in some setups it is not installed. Mitigated — it is an enhancer, not the renderer: preset HTML decks render deterministically without it; only `--design-from` needs it, and that falls back to a preset.
- **Theme coupling to `launch-release`:** a change to the theme schema affects both skills. Acceptable — single source of truth for themes is the point; documented in the ADR.

## Changelog

- **2026-05-30** — Initial draft (from RM-090 interview: split out as its own item; `map-system` complete-mode themed HTML deck, reusing launch-release themes + frontend-design).
- **2026-05-30** — Default flipped to `complete` + save + `html` + `dark-blue` theme (the deck is the new default; `--mode simplified --no-save` restores the old inline micro map). Added `--no-save`; default theme `dark-blue` (Primer palette, our own name — confirmed not a GitHub Pages theme).
- **2026-05-30** — Corrected the `frontend-design` dependency: it is an enhancer, not the renderer. Preset HTML decks render deterministically from the template; `frontend-design` only refines visuals and is required solely for `--design-from`. Mirrors the `launch-release` preset-vs-design-from contract.
