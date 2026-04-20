# release-announce — Cagan-style refinement (language, branding, communication)

**Date:** 2026-04-20
**Status:** Design approved, pending implementation plan
**Target skill:** `skills/release-announce/`

## Context

The current `release-announce` skill resolves refs → highlights → theme → templates → channel outputs. It ships 9 presets and generates 8 paste-ready channel messages. Themes expose aesthetic enums (`voice.tone`, `voice.persona`) and each channel template renders independently from raw highlights.

Reviewed through Marty Cagan's product premises (outcomes over outputs, customer obsession, missionaries not mercenaries), three gaps surfaced:

1. **Voice enums are aesthetic, not outcome-driven.** `calm`/`bold`/`guide`/`host` describe style; they never encode *why* the announcement exists from the reader's perspective.
2. **"Re-voice the changelog" is underspecified.** No framework translates technical change → user benefit → evidence. Quality depends entirely on the model's improvisation per run.
3. **No single narrative across channels.** Each channel template is independent. Email, Slack, X, and in-app-banner can drift into three different headlines and CTAs for the same release — the opposite of "missionaries, not mercenaries".

This spec closes those three gaps with additive, backwards-compatible changes.

## Goals

- Force every release announcement to encode *reader outcome*, not just aesthetic tone.
- Give the skill a structured translation from technical change to user benefit.
- Guarantee message consistency across every channel of a single release.
- Preserve the 9 existing presets, the CLI surface, and the `--design-from` contract.

## Non-goals

- Changing the CLI flags or the output directory layout.
- Replacing the existing aesthetic enums (`tone`, `persona`) — they remain, as modifiers.
- Auto-publishing to channels. Paste-ready remains the contract.
- Supporting multi-language announcements (out of scope; follow-up).

## Design

### 1. Theme schema: `intent` + `brand`

Two obligatory additions to the theme YAML schema:

```yaml
# existing fields (name, description, palette, typography, layout, voice) unchanged

intent: retaining   # retaining | expanding | repairing | educating

brand:
  signature: "Shipped with care by the Octopus team"
  cta_style: invitational   # imperative | invitational | informative
  hero_pattern: product-led # product-led | customer-led | team-led
```

**`intent`** answers "what should the existing reader *do or feel* after reading this?":

| Value | Reader outcome |
|-------|----------------|
| `retaining` | Feel safe/confident to keep using the product. |
| `expanding` | Realise they now have more than they did yesterday. |
| `repairing` | Trust that a known problem has been acknowledged and fixed. |
| `educating` | Learn how to use something new that already shipped. |

**`brand`** encodes identity that must survive a theme change:
- `signature` — a short line that recurs across channels (footer of email, last line of slack post, final slide).
- `cta_style` — governs verb choice in every rendered CTA.
  - `imperative`: "Update now", "Try it"
  - `invitational`: "Take a look when you have a minute"
  - `informative`: "Available in Settings → Integrations"
- `hero_pattern` — who is the protagonist of the hero section.
  - `product-led`: "v1.7 adds ..."
  - `customer-led`: "You asked for ..."
  - `team-led`: "We spent the last sprint on ..."

All three `brand` fields are required; `intent` is required.

Validation in `--design-from` is extended to require the new fields with the enum values above.

### 2. FBE: internal highlight structure

Between ref resolution and channel rendering, each highlight is expanded into a structured record:

```yaml
- title: "Tab-switch logout fixed"
  category: fix
  source: { tag: v1.7.1, rm: RM-042 }
  feature: "Auth refresh loop was retrying indefinitely on expired refresh tokens; now redirects to login after one failed attempt."
  benefit: "You stay signed in when you switch tabs, and won't hit a stuck spinner if your session truly expires."
  evidence: "Affected ~3% of daily active sessions; internal metrics show the loop cleared on 2026-04-18."
```

**Rules:**
- `feature` and `benefit` are required. `evidence` is optional but strongly encouraged (the renderer will prompt the model to produce it when absent and the source material supports it).
- `feature` may reuse CHANGELOG prose; `benefit` must be re-voiced (never copy-paste).
- `benefit` is written in second person addressing the existing user ("you can now…").

**Projection by `intent`** — channel renderers pick which fields to surface:

| Intent | Primary | Secondary | Tertiary |
|--------|---------|-----------|----------|
| `retaining` | evidence | benefit | — |
| `expanding` | benefit | feature | evidence |
| `repairing` | feature | evidence | benefit |
| `educating` | benefit | example from evidence | feature |

Compact channels (in-app-banner, x-announcement) show only the primary. Full channels (email, slides, index.html) show all three, styled by priority.

### 3. `narrative.yml` as canonical artefact

A new canonical file is always written:

```
docs/releases/<YYYY-MM-DD-slug>/narrative.yml
```

Schema:

```yaml
headline: "Fewer surprise logouts, faster exports, one new way to share."
proof: "The tab-switch logout is fixed, CSV exports are 4× faster, and shared links now carry viewer permissions."
cta:
  text: "See what's new"
  url: "https://app.example.com/whats-new"
```

**Constraints:**
- `headline` ≤ 80 characters, single sentence, reflects the `intent` of the theme.
- `proof` is one paragraph (≤ 280 chars) that lists 2–4 concrete points drawn from the highlights' `benefit`/`evidence` fields.
- `cta.text` follows the theme's `brand.cta_style`.

**Contract with channels:** every channel template renders *from* `narrative.yml` for the hero/opening and the CTA. No channel template may invent its own headline or CTA. Channels only decide *how* to expand, compact, or fragment the narrative:

- `email.html` — narrative in header + all highlights fully projected.
- `slack.md` / `discord.md` — narrative as preamble + top 3 highlights with primary field.
- `in-app-banner.md` — narrative `headline` only + `cta`.
- `x-announcement.md` — narrative `headline` as post 1; `proof` fragmented across posts 2–3 if thread.
- `whatsapp.md` — narrative `headline` + one highlight benefit per line.
- `status-page.md` — narrative `headline` as title, `proof` as body.
- `slides.html` — narrative as opening slide; highlights per subsequent slide.

### 4. Generation pipeline

New order of operations:

```
refs
  → raw highlights (CHANGELOG + git log + roadmap)
  → FBE expansion (feature / benefit / evidence per highlight)
  → theme load (palette + typography + layout + voice + intent + brand)
  → narrative synthesis (headline / proof / cta, constrained by intent + brand)
  → canonical artefacts (README.md, index.html, notes.md, theme.yml, narrative.yml)
  → channel projections (each channel reads narrative + projects highlights per intent)
```

FBE expansion happens before theme is loaded so it's theme-agnostic; narrative synthesis happens after because it depends on `intent` and `brand`.

### 5. Backwards compatibility

- **Existing preset themes** (`classic`, `jade`, `dark`, `bold`, `newsletter`, `sunset`, `ocean`, `terminal`, `paper`) get explicit `intent` and `brand` blocks committed in the same PR. Suggested defaults:

  | Preset | intent | cta_style | hero_pattern |
  |--------|--------|-----------|--------------|
  | classic | retaining | informative | product-led |
  | jade | retaining | invitational | customer-led |
  | dark | expanding | imperative | product-led |
  | bold | expanding | imperative | team-led |
  | newsletter | educating | invitational | customer-led |
  | sunset | retaining | invitational | team-led |
  | ocean | expanding | invitational | product-led |
  | terminal | repairing | informative | product-led |
  | paper | educating | informative | product-led |

  Signatures default to a neutral `"— the {{product}} team"` which consumer repos override.

- **Third-party themes** under `docs/release-announce/themes/` missing the new fields: load with hard-coded defaults (`intent: retaining`, `cta_style: informative`, `hero_pattern: product-led`, `signature: ""`) and emit a warning suggesting the repo add them.

- **CLI surface** unchanged. No new flags.

- **`--design-from`** validation gains the new required fields. The prompt template sent to `frontend-design` is extended to request `intent` and `brand` with their enum values.

### 6. File changes

- `skills/release-announce/SKILL.md` — new sections "Highlight Structure (FBE)", "Narrative", "Brand Kit"; updated "Theme Schema", "Output", "Generation pipeline".
- `skills/release-announce/templates/themes/*.yml` — add `intent` and `brand` to all 9 presets.
- `skills/release-announce/templates/channels/*.tmpl` — refactor each channel template to read `narrative` and project highlights by `intent` priority.
- `skills/release-announce/templates/readme.md.tmpl` — link to `narrative.yml` in the generated index.
- `skills/release-announce/templates/narrative.yml.tmpl` — **new**; scaffold for narrative synthesis.

## Testing

- **Unit-ish (template level):** snapshot tests for each of the 9 presets × 4 intents rendering the same fixture highlight set, asserting that (a) `narrative.yml` is byte-identical across channels of the same run, (b) in-app-banner contains only `headline` + `cta`, (c) email contains `signature`.
- **Validation:** feeding an old theme YAML (without `intent`/`brand`) triggers the warning and applies defaults; `--design-from` output missing `intent` fails fast.
- **Fixture release:** run `/octopus:release-announce v1.6.0..v1.7.0` against the Octopus repo itself; manually inspect that all 8 channels share the same headline and CTA.

## Open questions (to resolve during implementation)

- Should `narrative.yml` be editable-and-re-rendered in a future `--rerender` flag? (Out of scope for v1, but the file format should not block it.)
- Should `signature` support per-locale variants? (No for v1; multi-language is a separate follow-up.)

## Rollout

Single PR. No deprecation window needed since all changes are additive with safe defaults.
