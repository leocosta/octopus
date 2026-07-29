# Anglicize the launch-feature Portuguese-named templates

**Status:** design (approved 2026-07-29) · **Type:** refactor (patch) · **Scope:** `launch-feature` + `motion-promo` docs

## Context

Several `launch-feature` templates carry Portuguese names (`copy-lp`,
`changelog-vendedor`, `post-instagram`, `post-linkedin`, `thread-x`,
`roteiro-video`, and the top-level `video-roteiro`), which violate the
English-only repo rule and were deferred twice (in the email/WhatsApp spec and
the substance-voice review). The video pair is also a confusing reversed
duplicate: `templates/video-roteiro.md` (the override-default script guidance)
vs `channels/roteiro-video.md` (the channel output). The template basenames are
the generated-kit output filenames and the override-resolution keys, so a rename
touches references across the skill, its docs, the sibling `motion-promo` (prose
only — no functional path dependency), tests, and the site pages.

## Goals

- Rename the PT-named templates to consistent English (bare platform names,
  matching `email.md`/`whatsapp.md`), and align the reversed video pair.
- Update every reference so nothing dangles.
- Lock the cleanup with a "no PT names remain" test guard.

## Non-goals

- No template **content** changes — names + references only.
- No backward-compat/fallback for old override paths (clean break, documented).
- No change to already-English templates (`hashtags`, `caption-templates`,
  `viral-content-ideas`, `marketer-*`, `image-prompts`, `email`, `whatsapp`,
  `brand`, `voice`, `audience`).

## Design

### Renames (`git mv`)

| Current | New |
|---|---|
| `templates/channels/copy-lp.md` | `templates/channels/landing-copy.md` |
| `templates/channels/changelog-vendedor.md` | `templates/channels/commercial-changelog.md` |
| `templates/channels/post-instagram.md` | `templates/channels/instagram.md` |
| `templates/channels/post-linkedin.md` | `templates/channels/linkedin.md` |
| `templates/channels/thread-x.md` | `templates/channels/x.md` |
| `templates/channels/roteiro-video.md` | `templates/channels/video-script.md` |
| `templates/video-roteiro.md` | `templates/video-script.md` |

The channel `video-script.md` still requires the `video-script` override
(default `templates/video-script.md`); the dir disambiguates the two layers.

### Reference updates (the blast radius)

Update the `<name>` string in each:

- `skills/launch-feature/SKILL.md` — channel list + override-resolution set
  (`video-roteiro`→`video-script`) + the `roteiro-video.md`/`video-roteiro`
  render note.
- `skills/launch-feature/templates/channels/README.md` — the `video-roteiro:`
  frontmatter key and the "Files in this kit" list.
- `skills/launch-feature/templates/video-script.md` — its own override-path
  self-reference (`docs/marketing/video-roteiro.md` → `…/video-script.md`).
- `skills/motion-promo/SKILL.md` — the prose reference (`video-roteiro.md` →
  `video-script.md`; "roteiro" wording).
- `docs/site/skills/motion-promo.mdx` + `docs/site/pt-br/skills/motion-promo.mdx`.
- `tests/test_feature_to_market.sh` — the three channel file lists (~lines 67,
  76, 85).
- `docs/features/launch-feature.md` — the output-file list.
- `docs/site/skills/launch-feature.mdx` + `docs/site/pt-br/skills/launch-feature.mdx`
  — the kit-taxonomy table.

### Clean break for overrides (documented)

Override paths in user repos change (`docs/marketing/copy-lp.md` →
`docs/marketing/landing-copy.md`, `video-roteiro.md` → `video-script.md`, etc.).
No fallback. The **CHANGELOG entry lists the old → new mapping** so a user who
customized an override knows to rename it. Future kit output filenames also
change (generated artifact — not breaking).

## Testing

- Update `tests/test_feature_to_market.sh` to the new names.
- Add a **"no PT names remain" guard**: assert no template file under
  `skills/launch-feature/templates/` matches the old PT basenames, and that
  `SKILL.md` + the kit `README.md` reference none of them.
- Site build is mandatory after the `.mdx` edits: `bun run sync-content && bun run build` in `site/`.

## Verification

- `bash tests/test_feature_to_market.sh` → green (new names asserted, guard clean).
- `bash tests/test_bundles.sh` → green (`growth` unchanged).
- `grep -rIn` for each old PT basename across tracked files (excluding CHANGELOG
  and historical specs) → no hits.
- Site build green (EN + pt-br).
