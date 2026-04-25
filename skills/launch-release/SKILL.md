---
name: launch-release
description: >
  Generate a themed release announcement for existing users from one
  or more refs (tags, tag ranges, RM IDs). Produces canonical
  artifacts (landing HTML, plain notes, theme snapshot) and paste-ready
  channel messages (email, Slack, Discord, in-app banner, status page,
  X/Twitter, WhatsApp, slide deck). Supports preset themes and on-demand
  custom theme synthesis via frontend-design.
triggers:
  paths: ["CHANGELOG.md", "docs/releases/**", "releases/**"]
  keywords: ["release", "changelog", "announce", "version"]
  tools: []
---

# Release-Announce Protocol

## Overview

This skill announces what changed in a release to existing users.
Distinct from `launch-feature`, which handles acquisition / external
audiences. Inputs are versions or RMs; outputs are a themed landing
page + channel-specific paste-ready messages.

The default path is deterministic: refs → highlights → preset theme →
templates → output. When `--design-from="<prompt>"` is passed, the
skill invokes `frontend-design` to synthesize a new theme YAML, then
continues with the deterministic render.

## Invocation

```
/octopus:launch-release [<ref>...] [--theme=<name>] [--since=<tag>]
                           [--audience=<level>] [--channels=<list>]
                           [--design-from="<prompt>"] [--dry-run]
```

**Arguments:**

- `<ref>...` (zero or more) — tag (`v1.7.0`), tag range
  (`v1.5.0..v1.7.0`), or RM ID (`RM-008`). Union semantics.
  Default when none: `--since=<last-release-tag>..HEAD`.

**Options:**

- `--theme=<name>` — one of the installed themes. Default from
  `.octopus.yml theme:`, else `classic`.
- `--since=<tag>` — shortcut for `<tag>..HEAD` when no positional
  refs are given.
- `--audience=<user|developer|executive>` — tunes voice and detail.
  Default: `user`.
- `--channels=<list>` — subset of
  `email,slack,discord,in-app-banner,status-page,x-announcement,whatsapp,slides`.
  Default: `email,slack,in-app-banner`. `all` generates every channel.
  `none` skips `channels/` and writes only canonical artifacts.
- `--design-from="<prompt>"` — synthesize a custom theme via
  `frontend-design`. Overrides `--theme` with a warning when both are
  passed.
- `--dry-run` — print the plan and exit 0 without writing files.

## Input Resolution

Resolve each positional arg and build a unified highlights set:

1. **Tag** (`v\d+\.\d+\.\d+` or `v\d+\.\d+\.\d+-[\w.]+`): read the
   matching `## [version] - YYYY-MM-DD` section from `CHANGELOG.md`.
   Augment with `git log <prev-tag>..<tag> --pretty=short` for commit
   metadata. Derive `prev-tag` as the chronologically previous tag via
   `git tag --sort=-v:refname`.
2. **Tag range** (`vX..vY`): apply the tag rule for every tag between
   them (inclusive of `vY`, exclusive of `vX`); union.
3. **RM ID** (`^RM-\d+$`): read the `### RM-NNN …` section from
   `docs/roadmap.md`. Follow any `[Spec](...)` / `[Research](...)`
   links and read those too.
4. **Default** (no args): equivalent to `--since=<last-release-tag>`,
   where the last tag is the first output of
   `git tag --sort=-v:refname | head -n 1`.

Every highlight has: `title`, `summary`, `category` (`major` | `minor`
| `fix`, inferred from emoji prefix `✨`/`🎨`/`🐛` or from the
CHANGELOG section depth), `source` (tag + RM when available).

For each raw entry, rewrite the summary in user-facing language
constrained by the theme's `voice.tone` and `voice.persona` and the
`--audience` flag. Never copy changelog text verbatim into
user-facing channels — always re-voice.

Abort with the 5 nearest fuzzy matches when a ref cannot be resolved.

## Highlight Structure (FBE)

Between ref resolution and channel rendering, every highlight is expanded
into a three-field record before any output is produced:

```yaml
- title: "Tab-switch logout fixed"
  category: fix
  source: { tag: v1.7.1, rm: RM-042 }
  feature: "Auth refresh loop was retrying indefinitely on expired refresh tokens; now redirects to login after one failed attempt."
  benefit: "You stay signed in when you switch tabs, and won't hit a stuck spinner if your session truly expires."
  evidence: "Affected ~3% of daily active sessions; metrics cleared 2026-04-18."
```

- `feature` and `benefit` are required; `evidence` is encouraged whenever
  the source material supports it (numbers, before/after, concrete
  example). When no evidence is available, omit the field — never
  fabricate.
- `feature` may reuse CHANGELOG prose; `benefit` must be re-voiced in
  second person ("you can now…"). Never copy changelog text verbatim.
- The theme's `voice.tone` and `voice.persona` constrain wording; the
  `--audience` flag modulates depth.

**Projection by `intent`** — channel renderers pick which fields to
surface based on the theme's `intent`:

| intent | primary | secondary | tertiary |
|--------|---------|-----------|----------|
| `retaining` | evidence | benefit | — |
| `expanding` | benefit | feature | evidence |
| `repairing` | feature | evidence | benefit |
| `educating` | benefit | example from evidence | feature |

Compact channels (`in-app-banner`, `x-announcement`) render only the
primary field. Full channels (`email`, `slides`, `index.html`) render
all available fields, visually prioritised.

## Theme Resolution

Resolve the theme in this cascade (first match wins):

1. `--design-from="<prompt>"` — synthesize via `frontend-design`
   (see below) and persist.
2. `--theme=<name>` CLI flag.
3. `.octopus.yml` top-level `theme:` key.
4. Default: `classic`.

For a given theme name `N`, load the YAML from:

1. `docs/launch-release/themes/N.yml` (repo override, including any
   `--design-from` result)
2. `skills/launch-release/templates/themes/N.yml` (embedded preset)

Fail fast with a list of available theme names when `N` cannot be
resolved.

**Backwards compatibility:** a theme YAML loaded without intent or
`brand` (legacy themes written without intent) is handled with defaults
and emit a warning pointing to the offending file: `intent: retaining`,
`brand.cta_style: informative`, `brand.hero_pattern: product-led`,
`brand.signature: ""`. Do not fail. Third-party themes under
`docs/launch-release/themes/` written before this version continue to
work; consumer repos are nudged to add the fields on next run.

### `--design-from` contract with frontend-design

When `--design-from="<prompt>"` is passed:

1. Verify the `frontend-design` skill is loaded in the current agent
   environment. If not, abort with the message:
   "frontend-design skill not available — add it to .octopus.yml or
   pick a preset theme via --theme=<name>".
2. Invoke `frontend-design` with: "Generate a launch-release theme
   YAML matching the schema below. Inspired by: `<prompt>`.
   Return only valid YAML with the required fields." Attach the
   theme schema from `## Theme Schema` below.
3. Validate the returned YAML — required fields present, hex colors
   in `#RRGGBB` form, `layout.hero` in
   `{large,banner,minimal}`, `layout.grouping` in
   `{grid,timeline,stack}`, `layout.density` in
   `{compact,comfortable,spacious}`, `voice.tone` in
   `{calm,bold,playful,formal}`, `voice.persona` in
   `{guide,host,reporter,friend}`, `intent` is required and must be in
   `{retaining,expanding,repairing,educating}`, `brand.cta_style` in
   `{imperative,invitational,informative}`, `brand.hero_pattern` in
   `{product-led,customer-led,team-led}`, and `brand.signature` is a
   non-empty string.
4. Persist to `docs/launch-release/themes/<slug>.yml` where
   `<slug>` is the lowercase-kebab form of the prompt (max 40 chars).
5. Continue with that theme. Subsequent runs can reuse it via
   `--theme=<slug>`.

If both `--design-from` and `--theme` are passed,
`--design-from` wins; log a warning.

## Release Narrative

Before any channel is rendered, a canonical narrative file is written:

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

Constraints:

- `headline` ≤ 80 characters, single sentence, consistent with the
  theme's `intent`.
- `proof` ≤ 280 characters; 2–4 concrete points drawn from highlights'
  `benefit` and `evidence`.
- `cta.text` follows the theme's `brand.cta_style` register.
- `cta.url` resolves against the release landing page unless an override
  is provided.

**Contract with channels:** every channel template reads `narrative.yml`
for the hero opening and the CTA. **No channel may invent its own
headline or CTA.** Channels only decide *how* to expand, compact, or
fragment the narrative:

- `email.html` — narrative in header + all highlights fully projected.
- `slack.md` / `discord.md` — narrative as preamble + top 3 highlights
  with primary FBE field per theme intent.
- `in-app-banner.md` — `headline` + `cta` only.
- `x-announcement.md` — `headline` as post 1; `proof` fragmented across
  posts 2–3 if a thread.
- `whatsapp.md` — `headline` + one highlight benefit per line.
- `status-page.md` — `headline` as title, `proof` as body.
- `slides.html` — narrative as opening slide; highlights per subsequent
  slide.

## Generation Pipeline

Always execute in this order:

1. **Resolve refs** → raw highlights from `CHANGELOG.md`, `git log`,
   and `docs/roadmap.md`.
2. **FBE expansion** → rewrite each highlight into
   `{feature, benefit, evidence}`. Theme-agnostic; depends only on
   `--audience`.
3. **Theme load** → palette, typography, layout, voice, **intent**,
   **brand** (cascade from §Theme Resolution).
4. **Narrative synthesis** → `headline`, `proof`, `cta` derived from
   the FBE records and constrained by `intent` + `brand.cta_style`.
   Written to `narrative.yml`.
5. **Canonical artefacts** → `README.md`, `narrative.yml`, `index.html`,
   `notes.md`, `theme.yml`.
6. **Channel projections** → each channel reads `narrative.yml` for
   hero/CTA, then projects highlights using the FBE priority table for
   the theme's `intent`.

Channels never re-synthesise the narrative. If a channel needs a
shorter headline, it truncates `narrative.yml` — it does not invent
one.

## Output

Create `docs/releases/YYYY-MM-DD-<slug>/` where `<slug>` is derived
from the primary positional ref (a tag → that tag without the `v`
prefix; an RM → `rm-NNN`; multi-ref → `release-YYYY-MM-DD`).

**Canonical artifacts (always emitted):**

- `README.md` — index linking every other file + frontmatter with
  `generated_at`, `generated_by`, `refs`, `theme`, `audience`,
  `channels`.
- `narrative.yml` — canonical message-mother (headline, proof, CTA). All
  channels project from it.
- `index.html` — themed landing page. Hero + highlights grouped by
  category + CTA. All CSS inline; no external assets.
- `notes.md` — plain markdown fallback suitable for a docs site or
  screen reader.
- `theme.yml` — exact theme YAML used (snapshot, so re-rendering
  later with a different theme preserves history).

**Channel messages** (created under `channels/` based on
`--channels=`):

- `email.html` — email body (inline CSS, `<table>` layout, no
  `<script>` or `<style>` in `<body>`, `<head>` only for metadata).
- `slack.md` — Slack-flavored markdown (`*bold*`, `• bullet`,
  fenced code), with a preamble line ready for `@here` if desired.
- `discord.md` — Discord-flavored markdown with `**bold**`, `-# `
  subtext, embed-style sectioning.
- `in-app-banner.md` — one headline + one line of context + one CTA
  URL placeholder. Max 220 characters total.
- `status-page.md` — Statuspage-style update (title, body, component
  hint).
- `x-announcement.md` — post for **existing followers** (tone:
  "here's what we shipped for you"). Max 280 chars per post; may
  produce up to 3 posts as a thread.
- `whatsapp.md` — WhatsApp broadcast formatting (`*bold*`, single
  emoji per section, short lines).
- `slides.html` — see "Slides Channel" below.

Each channel file starts with a frontmatter block naming the refs,
theme, and channel, then the rendered content.

## Theme Schema

A theme is a YAML file at one of the paths in `## Theme Resolution`:

```yaml
name: jade
description: Elegant green palette with calm typography.
palette:
  background: "#0B1A17"
  surface: "#112925"
  primary: "#5FBF9A"
  accent: "#E8C9A0"
  muted: "#A2B5AF"
  text: "#F6F9F7"
typography:
  display: "Inter Tight, system-ui, sans-serif"
  body: "Inter, system-ui, sans-serif"
  mono: "JetBrains Mono, ui-monospace, monospace"
layout:
  hero: large             # large | banner | minimal
  grouping: grid          # grid | timeline | stack
  density: comfortable    # compact | comfortable | spacious
voice:
  tone: calm              # calm | bold | playful | formal
  persona: guide          # guide | host | reporter | friend
intent: retaining         # retaining | expanding | repairing | educating
brand:
  signature: "— the Octopus team"
  cta_style: invitational # imperative | invitational | informative
  hero_pattern: product-led # product-led | customer-led | team-led
```

All fields required. Colors must be `#RRGGBB`. Enum values exactly as
listed above.

**`intent`** governs the reader outcome the announcement is optimising for:

- `retaining` — reassure existing users that staying is the right call.
- `expanding` — show the user they have more capability than yesterday.
- `repairing` — acknowledge a visible issue and prove it is fixed.
- `educating` — teach the user how to use something already shipped.

**`brand`** carries identity that must survive a theme swap:

- `signature` — short recurring line appended to long-form channels
  (email footer, last slack line, final slide).
- `cta_style` — verb register for every CTA (`imperative` → "Update now",
  `invitational` → "Take a look when you have a minute", `informative` →
  "Available in Settings → Integrations").
- `hero_pattern` — protagonist of the hero section (`product-led` → the
  feature is the subject; `customer-led` → "You asked for…"; `team-led` →
  "We spent the sprint on…").

Nine presets ship in v1: `classic` (default), `jade`, `dark`, `bold`,
`newsletter`, `sunset`, `ocean`, `terminal`, `paper`.

## Slides Channel

`slides.html` is a single autocontained HTML file:

- One `<section class="slide">` per slide (title → hero → per-category
  grouped highlights → CTA).
- Inline CSS referencing `{{THEME_*}}` tokens. No external fonts (uses
  `system-ui` fallback when theme fonts not installed). No image
  assets.
- Inline `<script>` with ≤40 lines of vanilla JS implementing:
  keyboard navigation (`→`/`←`/`Space`/`PageUp`/`PageDown`), touch
  swipe (`touchstart`/`touchend` distance threshold), progress bar
  update, URL hash for the current slide.
- `@page` CSS rule with landscape orientation + page-break-after per
  slide so browser Print exports as a tidy PDF.

Slides are opt-in: they land in `channels/slides.html` only when
`slides` is in `--channels=` (or when `--channels=all`).

## Errors

Fail fast with actionable messages:

- **Unresolvable ref** → print the 5 nearest fuzzy matches (tags +
  RMs) and exit 1 before creating any files.
- **Not a git repo / no tags** → abort with "run `git tag` first or
  pass explicit refs".
- **`CHANGELOG.md` missing** → warn, continue with git log only.
- **`--design-from` without frontend-design available** → abort with
  guidance to install the skill or pick a preset.
- **`--design-from` output missing `intent` or `brand`** → abort with
  the list of missing required fields; the user retries with a more
  specific prompt.
- **Invalid theme YAML (from `--design-from` or a repo override)** →
  abort, list the validation failures.
- **Output directory already exists** → abort unless a `--force`
  flag is added in a future version (v1: never overwrite; user
  removes or renames the existing kit).
- **Unrecognized `--channels` value** → abort, list valid channel
  names.

## Composition

Pairs with:

- `launch-feature` — `launch-release` does retention;
  `launch-feature` does acquisition. A release often needs both:
  one post announcing to the market, one email announcing to
  existing users.
- `/octopus:release` — use `launch-release` right after the
  versioned release lands (PR merged, tag pushed) to generate the
  user-facing package.
- `frontend-design` — the only cross-skill call path in this skill,
  gated behind `--design-from`. See `## Theme Resolution`.

Output files are never published automatically. Paste-ready content
is the contract.
