---
name: release-announce
description: >
  Generate a themed release announcement for existing users from one
  or more refs (tags, tag ranges, RM IDs). Produces canonical
  artifacts (landing HTML, plain notes, theme snapshot) and paste-ready
  channel messages (email, Slack, Discord, in-app banner, status page,
  X/Twitter, WhatsApp, slide deck). Supports preset themes and on-demand
  custom theme synthesis via frontend-design.
---

# Release-Announce Protocol

## Overview

This skill announces what changed in a release to existing users.
Distinct from `feature-to-market`, which handles acquisition / external
audiences. Inputs are versions or RMs; outputs are a themed landing
page + channel-specific paste-ready messages.

The default path is deterministic: refs → highlights → preset theme →
templates → output. When `--design-from="<prompt>"` is passed, the
skill invokes `frontend-design` to synthesize a new theme YAML, then
continues with the deterministic render.

## Invocation

```
/octopus:release-announce [<ref>...] [--theme=<name>] [--since=<tag>]
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

## Theme Resolution

Resolve the theme in this cascade (first match wins):

1. `--design-from="<prompt>"` — synthesize via `frontend-design`
   (see below) and persist.
2. `--theme=<name>` CLI flag.
3. `.octopus.yml` top-level `theme:` key.
4. Default: `classic`.

For a given theme name `N`, load the YAML from:

1. `docs/release-announce/themes/N.yml` (repo override, including any
   `--design-from` result)
2. `skills/release-announce/templates/themes/N.yml` (embedded preset)

Fail fast with a list of available theme names when `N` cannot be
resolved.

### `--design-from` contract with frontend-design

When `--design-from="<prompt>"` is passed:

1. Verify the `frontend-design` skill is loaded in the current agent
   environment. If not, abort with the message:
   "frontend-design skill not available — add it to .octopus.yml or
   pick a preset theme via --theme=<name>".
2. Invoke `frontend-design` with: "Generate a release-announce theme
   YAML matching the schema below. Inspired by: `<prompt>`.
   Return only valid YAML with the required fields." Attach the
   theme schema from `## Theme Schema` below.
3. Validate the returned YAML — required fields present, hex colors
   in `#RRGGBB` form, `layout.hero` in
   `{large,banner,minimal}`, `layout.grouping` in
   `{grid,timeline,stack}`, `layout.density` in
   `{compact,comfortable,spacious}`, `voice.tone` in
   `{calm,bold,playful,formal}`, `voice.persona` in
   `{guide,host,reporter,friend}`.
4. Persist to `docs/release-announce/themes/<slug>.yml` where
   `<slug>` is the lowercase-kebab form of the prompt (max 40 chars).
5. Continue with that theme. Subsequent runs can reuse it via
   `--theme=<slug>`.

If both `--design-from` and `--theme` are passed,
`--design-from` wins; log a warning.
