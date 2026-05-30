# ADR-003: map-system gains a complete-mode HTML deck (and it becomes the default)

## Status

Accepted — 2026-05-30

## Context

`map-system` was a deliberately tiny skill: a one-shot ~30-line textual
orientation map, explicitly anti-exhaustive. RM-098 needs it to also produce a
**shareable, self-contained, themed HTML presentation** of a repository
(overview, business insights, diagrams, API contracts) that `onboarding`
(RM-090) walks a new engineer through and a manager reuses. Two interface
choices here are hard to reverse once `onboarding` and the theme presets depend
on them, so they are recorded. Triggered by
`docs/specs/map-system-presentation.md`.

## Sources

- `docs/specs/map-system-presentation.md` — the spec.
- `skills/map-system/SKILL.md` — the prior micro-skill contract.
- `skills/launch-release/SKILL.md` + `templates/themes/*` — the theme schema and
  presets reused here.
- RM-090 interview (2026-05-30) — where the requirement and defaults were set.

## Decision

1. Evolve `map-system` with a **`complete` mode** that renders a self-contained
   themed HTML deck, **reusing the `launch-release` theme machinery** (schema,
   presets, `--design-from` synthesis via `frontend-design`) rather than a new
   styling system. Keep `simplified` as the micro textual mode.
2. Make the deck the **new default** (`complete` + save + `html` + `dark-blue`);
   the old behaviour is preserved as `--mode simplified --no-save`.

## Alternatives Considered

### A — Two modes on one skill, deck as default (chosen)

- **Pros:** one home for "map this repo"; the lightweight map stays available;
  the deck reuses a proven theme system; the default matches the dominant use
  (a manager/engineer wanting the repo picture).
- **Cons:** a bare invocation now crawls and writes a file (breaking change); the
  skill carries two distinct disciplines.

### B — A separate `system-presentation` skill, map-system unchanged

- **Pros:** clean identities; map-system stays a pure micro-skill.
- **Cons:** two skills with overlapping intent; the user explicitly asked to
  evolve `map-system`, not add a skill. Rejected.

### C — Complete mode additive, simplified stays the default

- **Pros:** no breaking change.
- **Cons:** the dominant use (the deck) would always need flags; the user chose
  the deck as the default. Rejected.

### Fork the styling system (rejected sub-option)

A bespoke theming layer was rejected — `launch-release` already owns a theme
schema, presets, and `frontend-design` synthesis. One source of truth for themes
is worth the coupling.

## Consequences

### Positive

- A reusable, version-controlled `docs/system-map/<repo>.html` asset per repo.
- `onboarding` gets its presentation surface for free.
- Themes (`dark-blue`, `dark-jade`, `light-jade`) are shared across both skills.

### Negative

- Breaking default: a bare `map-system` now crawls and writes a committed file.
  Bounded by manual-invocation-only and the `--mode simplified --no-save` escape
  hatch. It does not add a hard `frontend-design` dependency — preset HTML decks
  render deterministically from the template without it.
- A change to the `launch-release` theme schema now affects `map-system` too.

### Risks

- Stale committed decks — mitigated: cheap to regenerate; dated on the cover.
- `frontend-design` absent — mitigated: it is an enhancer, not the renderer.
  Preset HTML decks still render from the template; only `--design-from` needs
  it, and that falls back to a preset.
