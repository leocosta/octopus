---
name: feature-to-market
description: >
  Turn a completed feature (RM-NNN, spec path, research path, or PR)
  into a versioned multi-channel launch kit under
  docs/marketing/launches/YYYY-MM-DD-<slug>/ — posts, email, LP copy,
  commercial changelog, video script, and optional image assets.
---

# Feature-to-Market Protocol

## Overview

This skill turns a completed feature into a publish-ready launch kit. It
resolves the feature reference, collects context (spec, research, commits),
applies a brand/voice override cascade, renders per-channel templates, and
optionally generates images using free providers.

The skill composes with the existing `social-media` role for copywriting
judgment (hook choice, channel adaptation) — it does not duplicate that role.
This skill owns orchestration: ref resolution, override cascade, file writing,
and image generation.

## Invocation

```
/octopus:feature-to-market <ref> [options]
```

**Arguments:**

- `<ref>` (required) — one of:
  - Roadmap ID: `RM-008`
  - Spec/research path: `docs/specs/automated-billing.md`
  - Pull request: `#123`, `PR-123`, or full GitHub URL

**Options:**

- `--channels=<list>` — comma-separated subset of
  `instagram,linkedin,x,email,lp,changelog,video`. Default: all applicable.
- `--dry-run` — print generated content to chat without creating files.
- `--no-images` — skip image generation even if a provider is configured.
- `--images-only` — regenerate only images; reuse existing text artifacts.
- `--angle=<label>` — force a specific hook/angle from the hooks override,
  bypassing automatic selection.
- `--force` — overwrite an existing launch directory for the same date/slug.

## Input Resolution

Resolve `<ref>` into a context bundle using this decision tree:

1. **Roadmap ID** — `<ref>` matches `^RM-\d+$`.
   - Read `docs/roadmap.md`. Extract the `### RM-NNN …` section (from the
     heading until the next `### ` or `---` separator).
   - Follow any `[Spec](...)`, `[Research](...)` links inside that section
     and read the linked documents.
   - Abort if the RM is not found; print the 5 nearest RM IDs.
2. **Path** — `<ref>` is a filesystem path that exists.
   - Read the file. If it mentions `RM-\d+`, also pull that roadmap entry.
3. **PR reference** — `<ref>` matches `^#?\d+$`, `^PR-\d+$`, or a GitHub URL.
   - Run `gh pr view <number> --json title,body,labels,commits,files`.
   - If `gh` is missing, fall back to `git log` scoped to the merge commit.
4. **Otherwise** — fuzzy-match across roadmap IDs and `docs/specs/*.md` file
   names; print the top 5 suggestions and exit.

Always augment the context with `git log --oneline -n 30 -- <resolved files>`
when file paths are known, so the kit reflects what actually changed.

If the current language cannot be inferred from `.octopus.yml` (`language:`
field), detect it from the resolved ref content (majority of the first 500
words).

## Override Cascade

For each of the override names — `brand`, `voice`, `audience`, `hashtags`,
`social-media-guide`, `social-media-hooks`, `caption-templates`,
`viral-content-ideas`, `video-roteiro` — resolve the first path that exists:

1. `docs/marketing/<name>.md` (canonical Octopus location)
2. `docs/<NAME_UPPER>.md` where `NAME_UPPER` is the name uppercased with
   underscores (e.g. `SOCIAL_MEDIA_GUIDE.md`). This keeps compatibility with
   repos like Tatame that already have these files at the root of `docs/`.
3. Embedded default at `skills/feature-to-market/templates/<name>.md` inside
   the Octopus installation.

Record which source was used per override in the launch-kit `README.md`
frontmatter (`overrides:` map) so the reviewer sees where each style decision
came from.

## Output Assembly

Create `docs/marketing/launches/YYYY-MM-DD-<slug>/` in the target repository
where:

- `YYYY-MM-DD` is today's date (UTC or local, use `date -u +%F`).
- `<slug>` is derived from the feature title: lowercase ASCII, non-alphanumeric
  runs collapsed to `-`, trimmed to 40 chars. Example: "Card de consentimento
  de taxas" → `card-de-consentimento-de-taxas`.

If the directory already exists:
- Without `--force`: abort with an error message suggesting `--force` or a
  different slug (append a short discriminator).
- With `--force`: overwrite files inside, but preserve `images/` unless
  `--images-only` is passed.

For each selected channel, read the matching template under
`skills/feature-to-market/templates/channels/<name>.md`, fill every `{{PLACEHOLDER}}`
with content grounded in the resolved feature context, and write it to the
launch directory.

**Placeholder rules:**

- Never leave a placeholder literal in the output.
- If a placeholder has no grounded answer, remove the whole line or block and
  add a `<!-- TODO: <what's missing> -->` comment nearby.
- `{{ANGLE}}` must come from `social-media-hooks` (override or default); pick
  one angle and reuse it across all channels for coherence.
- `{{LANGUAGE}}` is the detected language (e.g. `pt-BR`, `en`).

**README.md assembly:**

Always write `README.md` last, after every other file is generated. Fill the
`overrides:` map with the source used per override name (one of: the absolute
repo path, or `embedded` when the default was used).

**Channel selection:**

- Default: all channels whose override source exists OR whose embedded default
  exists, EXCEPT `roteiro-video.md` which requires a `video-roteiro` override
  in the target repo (embedded default alone is not enough to produce a video
  script — the repo-specific style matters too much).
- With `--channels=<list>`: only those channels, regardless of override
  presence.

## Image Generation

Run after all text artifacts are written, unless `--no-images` is set. Skip
entirely when `--channels` excludes every image-bearing surface.

**Provider resolution order:**

1. **Gemini** — if `GEMINI_API_KEY` is set in the environment. Use the current
   Gemini image-generation endpoint (`gemini-2.5-flash-image` family). Save
   each PNG to `images/<name>.png` in the launch directory.

   Reference call (the agent adapts the model name to whatever is current):

   ```bash
   curl -sSf \
     "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$GEMINI_API_KEY" \
     -H "Content-Type: application/json" \
     -d "$(jq -n --arg prompt "$PROMPT" '{contents:[{parts:[{text:$prompt}]}]}')" \
     | jq -r '.candidates[0].content.parts[] | select(.inlineData) | .inlineData.data' \
     | base64 -d > "$OUT_PATH"
   ```

   If the Gemini call fails (HTTP non-2xx, empty payload, rate limit),
   fall through to the next provider.

2. **Pollinations.ai** — no key required. HTTP GET against
   `https://image.pollinations.ai/prompt/<URL_ENCODED_PROMPT>?width=<W>&height=<H>&nologo=true`.
   Save the response body as PNG.

   ```bash
   encoded_prompt="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$PROMPT")"
   curl -sSf "https://image.pollinations.ai/prompt/${encoded_prompt}?width=${W}&height=${H}&nologo=true" \
     -o "$OUT_PATH"
   ```

3. **None** — if both fail and neither is configured: write only
   `image-prompts.md`, set `images_provider: none` in `README.md`, and print
   a note to the user explaining how to enable providers.

**Aspect ratios:**

| File | Size |
|---|---|
| `images/instagram-1x1.png` | 1080×1080 |
| `images/linkedin-1.91x1.png` | 1200×628 |
| `images/x-16x9.png` | 1200×675 |
| `images/lp-hero-16x9.png` | 1600×900 |

**Brand injection:**

When `brand.md` (override or default) defines a palette or logo, prepend the
constraint to every prompt, e.g.:

> "Brand palette: #111111, #F5F5F5, accent #2F80ED. Avoid photographic
> realism. Typography-heavy layout. No stock-photo people."

Log the final prompt used for each image as a comment in `image-prompts.md`.
