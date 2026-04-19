# Feature-to-Market

Turn a completed feature into a publish-ready, multi-channel launch kit in
seconds. Works with any Octopus-managed repo.

## When to use

When you've just merged a feature (or marked a roadmap item completed) and you
want Instagram, LinkedIn, X, email, LP copy, a commercial changelog, a video
script, and optional images — ready to review and publish.

## Enable

Add to `.octopus.yml`:

```yaml
skills:
  - feature-to-market
```

Run `octopus setup` to install the slash command in your agent of choice.

## Use

```
/octopus:feature-to-market RM-008
/octopus:feature-to-market RM-008 --channels=email,linkedin
/octopus:feature-to-market docs/specs/billing.md --no-images
/octopus:feature-to-market #123 --dry-run
```

## Overrides (recommended)

The skill works out-of-the-box with embedded defaults, but the output is
far better when your repo provides brand/voice overrides. Create any of
these (first-match wins per name):

- `docs/marketing/brand.md`
- `docs/marketing/voice.md`
- `docs/marketing/audience.md`
- `docs/marketing/hashtags.md`
- `docs/marketing/social-media-guide.md`
- `docs/marketing/social-media-hooks.md`
- `docs/marketing/caption-templates.md`
- `docs/marketing/viral-content-ideas.md`
- `docs/marketing/video-roteiro.md`

For compatibility with repos that already keep these at the root of `docs/`
(uppercase with underscores, e.g. `SOCIAL_MEDIA_GUIDE.md`), the skill also
reads those locations.

## Image generation

The skill always writes `image-prompts.md`. It additionally produces PNGs
when one of these is configured:

1. `GEMINI_API_KEY` (free tier at https://aistudio.google.com/)
2. Pollinations.ai — no configuration required; used as fallback.

Use `--no-images` to skip entirely.

## Output

A directory `docs/marketing/launches/YYYY-MM-DD-<slug>/` containing:

- `README.md` — kit index + chosen angle + source refs
- `post-instagram.md`, `post-linkedin.md`, `thread-x.md`
- `email-lancamento.md`, `copy-lp.md`, `changelog-vendedor.md`
- `roteiro-video.md` (only when the repo has a `video-roteiro` override)
- `image-prompts.md`
- `images/` (when a provider ran)

## Review before publishing

The kit is a draft. The `social-media` role and this skill agree on one rule:
nothing gets posted without human review.
