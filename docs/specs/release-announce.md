# Spec: Release-Announce

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-19 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |

## Problem Statement

Teams that ship continuously have two distinct communication jobs:

1. **Acquisition** — telling people who *don't use the product* that a
   new feature exists, hoping they try. This is what `feature-to-market`
   already solves: Instagram / LinkedIn / X / email-to-market / LP copy.
2. **Retention / in-product** — telling people who *already use the
   product* what changed in a release. Changelog is the technical
   answer; but a raw changelog is too dry for end users, hard to point
   at in a call, and doesn't pair with a polished visual surface.

Today, between v1.6.0 and v1.7.0 shipping, a team that wants to send a
"here's what's new this month" message to existing customers has no
Octopus skill to help. They hand-write an email, hand-style it, paste
variants into Slack and status page — and either skip the release
announcement or do a rushed version.

The Octopus workflow already produces richly structured artifacts the
skill can consume: `CHANGELOG.md` entries (already narrative, per
`/octopus:release` convention), `docs/roadmap.md` (RM items with
rationale), spec/research docs linked from RMs. What's missing is the
packaging layer that turns this substrate into something a product
team can send to its base without extra writing or styling work.

## Goals

- Add a skill `octopus:release-announce` that, given one or more refs
  (tags, tag ranges, RM IDs), generates a themed release announcement
  pack aimed at **existing users**.
- Produce two tiers of output: **canonical** (themed landing HTML, plain
  notes, theme snapshot) and **channels** (paste-ready messages for
  Slack, email, Discord, in-app banner, status page, X/Twitter,
  WhatsApp, and an autocontained slide deck).
- Support a catalog of preset themes (`classic`, `jade`, `dark`,
  `bold`, `newsletter`) selectable via `.octopus.yml theme:` or per-run
  `--theme=<name>`.
- Support on-demand custom theme synthesis via
  `--design-from="<prompt>"` that delegates **theme creation only** to
  the `frontend-design` skill, persists the result, and uses it for
  the current render.
- Keep everything deterministic when no `--design-from` is used — same
  inputs produce the same output, so teams can re-run to regenerate
  with a different theme or channel subset.
- Register as a new skill under the existing `growth` bundle.

## Non-Goals

- Publishing (sending email, posting to Slack/Discord, deploying a
  site). Output is paste-ready; transport is user-driven.
- Replacing `feature-to-market`. That skill stays focused on
  acquisition / external audiences; `release-announce` is for
  retention / existing users.
- WYSIWYG theme editor. Themes are YAML by design.
- Multi-language in a single run. Language comes from
  `.octopus.yml language.docs` (or the auto-detected default).
- A/B variants of copy.
- `--high-fidelity` mode where the whole HTML render is delegated to
  `frontend-design`. Deferred to v2; v1's determinism is a feature.
- Native changelog parsing for arbitrary formats beyond the Octopus
  convention (`## [version] - YYYY-MM-DD` + narrative paragraphs).
  Other formats warn and fall back to raw git log.

## Design

### Overview

A pure-markdown Octopus skill (same shape as `feature-to-market`,
`money-review`, `tenant-scope-audit`). Lives at
`skills/release-announce/SKILL.md` + templates dir. The skill:

1. Resolves the input refs (tags, tag ranges, RM IDs) into a unified
   highlight set.
2. Resolves the theme (preset, repo override, or on-demand via
   `frontend-design`).
3. Renders canonical artifacts + selected channel messages from
   templates into a dated output directory.

The `frontend-design` skill is invoked **only** when
`--design-from="<prompt>"` is passed, and only to synthesize a theme
YAML — not to render the final HTML.

### Detailed Design

#### Invocation

```
/octopus:release-announce [<ref>...] [--theme=<name>] [--since=<tag>]
                           [--audience=<level>] [--channels=<list>]
                           [--design-from="<prompt>"] [--dry-run]
```

**Positional refs** (zero or more, union semantics):
- Tag: `v1.7.0`
- Tag range: `v1.5.0..v1.7.0`
- RM ID: `RM-008`

**Default when no ref is passed:** `--since=<last-release-tag>..HEAD`.

**Flags:**
- `--theme=<name>`: resolves in this order — CLI flag → `.octopus.yml
  theme:` → `classic`.
- `--since=<tag>`: shortcut for `<tag>..HEAD` when no positional refs
  are given.
- `--audience=<user|developer|executive>`: tunes voice and detail.
  Default `user`.
- `--channels=<list>`: comma-separated subset of
  `email,slack,discord,in-app-banner,status-page,x-announcement,whatsapp,slides`.
  Defaults: `email,slack,in-app-banner` (sensible minimum).
  `--channels=all` → every channel. `--channels=none` → only canonical
  artifacts, skip `channels/` directory.
- `--design-from="<prompt>"`: invoke `frontend-design` to synthesize a
  new theme YAML from the prompt; persist to
  `docs/releases/themes/<slug>.yml`; use for this run. Overrides
  `--theme` if both are passed (warn and proceed).
- `--dry-run`: print the plan (refs resolved, theme chosen, channels
  to render) and exit 0 without writing files.

#### Pipeline

1. **Resolve refs.** For each positional arg, classify and load:
   - Tag → `CHANGELOG.md` section for that version + `git log
     <prev-tag>..<tag>` for commit metadata.
   - Tag range → repeat per tag in range, union.
   - RM ID → `docs/roadmap.md` section (via the `feature-to-market`
     lookup pattern) + linked spec/research.

   Output: a `highlights` list — each entry has `title`, `summary`,
   `category` (`major` / `minor` / `fix`), `source` (version + RM).

   Abort with fuzzy match suggestions when a ref can't be resolved.

2. **Extract highlights.** For each raw entry the agent writes a
   user-facing summary (not a changelog line) — what it does for the
   user, why they should care, in the voice hinted by the theme
   (`voice.tone`, `voice.persona`) and tuned to `--audience`.

3. **Resolve theme.** Cascade: CLI `--theme` → `--design-from` output →
   `docs/release-announce/themes/<name>.yml` (repo override) →
   `skills/release-announce/templates/themes/<name>.yml` (embedded).
   Fail fast if a named theme does not exist.

4. **Render.** Read each template, substitute placeholders
   (`{{THEME_*}}`, `{{HIGHLIGHT_N_*}}`, `{{RELEASE_TITLE}}`,
   `{{RELEASE_DATE}}`, …), write each artifact.

5. **Write kit.** Persist everything under
   `docs/releases/YYYY-MM-DD-<slug>/`. Slug is derived from the
   primary ref (tag or RM); multi-ref runs use `release-<date>` as
   fallback.

#### Output structure

```
docs/releases/2026-04-19-v1.7.0/
├── README.md             # index + frontmatter
├── index.html            # themed landing page
├── notes.md              # plain markdown fallback
├── theme.yml             # snapshot of the theme effectively used
└── channels/
    ├── email.html        # email body (inline CSS, tables, no JS)
    ├── slack.md          # Slack-formatted post (mrkdwn)
    ├── discord.md        # Discord-formatted post
    ├── in-app-banner.md  # 1 headline + 1 line + CTA
    ├── status-page.md    # Statuspage-style update
    ├── x-announcement.md # post for existing followers (not acquisition)
    ├── whatsapp.md       # broadcast list format, *bold* + emojis
    └── slides.html       # autocontained slide deck (keyboard nav, printable)
```

Each file has frontmatter with `generated_at`, `generated_by`,
`refs`, `theme`, `audience` for traceability.

#### Theme schema

`themes/<name>.yml`:

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
  hero: large          # large | banner | minimal
  grouping: grid       # grid | timeline | stack
  density: comfortable # compact | comfortable | spacious
voice:
  tone: calm           # calm | bold | playful | formal
  persona: guide       # guide | host | reporter | friend
```

#### Themes shipped in v1

| Name | Feel | When to pick |
|---|---|---|
| `classic` (default) | Minimal newsletter — B&W + single accent | Safe neutral, enterprise / formal context |
| `jade` | Calm green, elegant typography | Wellness, health, sustainability, calm brands |
| `dark` | Dark background, modern accent, high contrast | Dev tools, gaming, modern SaaS |
| `bold` | Vibrant accents, large display typography | Consumer apps, marketing-heavy moments |
| `newsletter` | Plain, high-density (more text per page) | Long release notes with many bullets |
| `sunset` | Warm orange → pink gradient, friendly serif display | Consumer lifestyle, community-driven products |
| `ocean` | Cool blues + white, professional calm | Fintech, B2B SaaS, enterprise |
| `terminal` | Green mono-on-black, JetBrains Mono throughout | Dev tools, CLIs, hacker-aesthetic products |
| `paper` | Cream background, warm browns, serif body | Editorial, literary, reflective long-form updates |

#### Slides channel

`slides.html` is a single HTML file with inline CSS + ~20 lines of
vanilla JS for navigation. No external libraries. One `<section>` per
slide:

1. Title slide — release name + date + theme accent
2. Hero slide — top 1 highlight (major category)
3. Grouped highlights — one slide per major highlight, batched by
   category (major / minor / fixes)
4. CTA slide — link to full notes + contact / docs

Navigation: `→` / `←` / `Space` / swipe (touch). Print-to-PDF supported
(page break between slides via `@page` CSS).

#### Frontend-design integration

When `--design-from="<prompt>"` is passed:

1. Validate that the `frontend-design` skill is available in the
   current agent's environment (warn if not, abort with instructions).
2. Delegate to `frontend-design` with a request of the form:
   > Generate a release-announce theme YAML matching this schema: …
   > Inspired by: `<prompt>`.
3. Validate the returned YAML against the schema (required fields,
   hex colors, enum values for layout/voice).
4. Persist to `docs/release-announce/themes/<slug>.yml` where `<slug>`
   is derived from the prompt (`retro synthwave` → `retro-synthwave`).
5. Use the new theme for the current render and record it in
   `theme.yml` under the output directory.

Subsequent runs can reuse the persisted theme with
`--theme=retro-synthwave`.

#### Bundle membership

Add to `bundles/growth.yml`:

```yaml
skills:
  - feature-to-market
  - release-announce
```

Rationale: both are product communication skills; one for acquisition,
one for retention. Grouping them in `growth` keeps the bundle count
small in v1. If a future wave of retention skills (churn win-back,
onboarding emails) lands, we spin off a dedicated `retention` bundle.

### Migration / Backward Compatibility

- No breaking changes. Skill is additive.
- `.octopus.yml` gains optional keys `theme:` and `releaseChannels:`;
  both safe to add without migration.
- Existing `growth` bundle gains `release-announce` — users who
  already selected `growth` and re-run `octopus setup` get the new
  skill. Users who prefer only `feature-to-market` can switch to
  explicit `skills:` in Full mode.

## Implementation Plan

1. `skills/release-announce/SKILL.md` — frontmatter + Overview +
   Invocation sections.
2. `skills/release-announce/templates/themes/{classic,jade,dark,bold,newsletter,sunset,ocean,terminal,paper}.yml` — nine preset themes.
3. `skills/release-announce/templates/html/index.html.tmpl` — landing
   page template, theme-token placeholders.
4. `skills/release-announce/templates/html/email.html.tmpl` — email
   body (inline CSS, `<table>` layout, no `<script>`).
5. `skills/release-announce/templates/html/slides.html.tmpl` — slide
   deck with inline CSS + vanilla JS nav.
6. `skills/release-announce/templates/channels/{slack,discord,in-app-banner,status-page,x-announcement,whatsapp}.md.tmpl` — six channel message templates.
7. `skills/release-announce/templates/notes.md.tmpl`,
   `readme.md.tmpl` — canonical non-HTML artifacts.
8. `commands/release-announce.md` — thin slash command dispatching to
   the skill.
9. `cli/lib/setup-wizard.sh` — register `release-announce` in items
   array, hints, and legend (alphabetical placement).
10. `bundles/growth.yml` — add `release-announce` to the skills list.
11. `docs/features/release-announce.md` — tutorial.
12. `docs/features/skills.md` — new row with bundle membership.
13. `README.md` — add `release-announce` to the Available skills
    comment.
14. `tests/test_release_announce.sh` — structural tests covering
    skill file, command, wizard, bundle, all templates, documented
    sections, `--design-from` contract mention.

## Context for Agents

**Knowledge modules**: none new.
**Implementing roles**: `backend-specialist` (bash CLI + skill markdown), `frontend-specialist` (HTML/CSS templates), `tech-writer` (tutorial + README).
**Related ADRs**: consider an ADR explaining why themes are YAML data rather than code, and why `frontend-design` is called only for theme synthesis.
**Skills needed**: `adr`, `feature-lifecycle`.
**Bundle**: `growth` (existing) — append to the existing skills list in `bundles/growth.yml`.

**Constraints**:
- Pure bash + python3 (already in deps) for YAML parsing.
- HTML templates must render without external assets — CSS inline,
  fonts `system-ui` fallback, no CDN dependencies, no JS frameworks.
  The slides deck is allowed ≤40 lines of vanilla JS for navigation.
- Email template must pass the common-denominator email-client rules:
  inline CSS, `<table>`-based layout, no `<script>`/`<style>` tags in
  the body, images referenced by absolute URL (not bundled).
- Deterministic default path — same inputs produce the same output
  when `--design-from` is not passed. Randomness is not allowed in
  templates (no timestamps outside `generated_at` frontmatter).
- `frontend-design` is invoked **only** via `--design-from`. The
  default path never calls another skill.
- Output is paste-ready, not published. Never attempt to send email,
  post to Slack, deploy a site.

## Testing Strategy

- **Structural (bash)**: skill file exists with correct frontmatter;
  every documented section present (`## Invocation`, `## Input
  Resolution`, `## Theme Resolution`, `## Output`, `## Errors`,
  `## Composition`); all five preset themes present; all HTML + MD
  templates present; command file + wizard registration + bundle
  entry present; README and skills.md rows present.
- **Integration (manual)**: run the skill against the current
  Octopus repo's `v1.5.0..v1.7.0` range and confirm the generated
  kit matches expectations visually (open `index.html` + `slides.html`
  in a browser).
- **Channel determinism**: re-running with the same refs and theme
  produces byte-identical output in every non-timestamp field.

## Risks

- **Email client compatibility** — HTML email is notoriously
  fragile. Mitigation: template follows the "email bulletproof"
  pattern (tables + inline CSS + no modern selectors); tutorial
  recommends testing with Litmus / emailonacid before sending.
- **Theme over-proliferation** — users might generate dozens of
  one-off themes via `--design-from`. Mitigation: the tutorial
  encourages naming and reusing themes; the repo override path is
  explicit.
- **Frontend-design unavailability** — not every agent environment
  has `frontend-design`. Mitigation: `--design-from` fails loudly with
  a clear message if the skill isn't loaded; presets always work.
- **Scope creep into publishing** — users will ask for "also send to
  Slack". Mitigation: spec is explicit that publishing is out of
  scope; document as a potential future skill
  (`release-publish`).
- **LLM drift in copy tone across runs** — same theme, slightly
  different phrasing each time. Mitigation: `voice.tone` and
  `voice.persona` fields in the theme constrain the LLM; tutorial
  shows how to anchor tone.

## Cagan Refinement (2026-04-20)

A companion design doc extends this spec with three additions driven by
Marty Cagan's product premises (outcomes over outputs, customer
obsession, missionaries not mercenaries). See
`docs/specs/2026-04-20-release-announce-cagan-refinement-design.md` for
the full design.

Summary of additions (authoritative schema lives in SKILL.md):

1. **Theme schema — `intent` + `brand` blocks.** Every theme declares
   one of `retaining | expanding | repairing | educating` plus a
   `brand` block with `signature`, `cta_style`
   (`imperative | invitational | informative`), and `hero_pattern`
   (`product-led | customer-led | team-led`). The nine presets ship
   with explicit defaults; legacy themes without these fields load with
   `intent: retaining` + neutral brand defaults and a warning.

2. **Highlight Structure (FBE).** Between ref resolution and channel
   rendering, every highlight is expanded into `feature`, `benefit`,
   and (when available) `evidence`. Channels project these fields in a
   priority order determined by the theme's `intent` — compact channels
   show only the primary field; full channels show all three.

3. **Release Narrative as canonical artefact.** A new
   `narrative.yml` (headline ≤ 80 chars, proof ≤ 280 chars, cta
   text + url) is written alongside the other canonical files. Every
   channel template reads from `narrative.yml` for the hero/CTA; no
   channel may invent its own headline or CTA.

Generation pipeline order, after the refinement:
`refs → FBE expansion → theme load → narrative synthesis →
canonical artefacts → channel projections`.

Backwards compatibility is preserved — no CLI flag changes, no
breaking output-directory changes. Legacy third-party themes continue
to work with a warning.

See SKILL.md §Highlight Structure (FBE), §Release Narrative,
§Generation Pipeline for the authoritative contract.

## Changelog

- **2026-04-19** — Initial draft.
- **2026-04-20** — Added Cagan refinement (intent + brand, FBE,
  narrative.yml); see companion design doc.
