# Content Images Skill — Design Spec

**Date:** 2026-04-27
**Status:** Draft

## Context

The tatame project has a `scripts/generate-og-images.mjs` that generates blog
cover images using Google Gemini Imagen, plus a companion
`generate-carousel.mjs` for Instagram carousels. Both scripts are project-specific
(hardcoded prompts, fixed output paths) and are used in conjunction with the
`social-media` subagent to create content campaigns.

The goal is to generalize this pattern as a reusable Octopus capability:

- A **`content-images` skill** that instructs Claude to generate brand-consistent
  images for any project from a conversational briefing
- An **update to the `social-media` agent** that asks, at the end of any content
  generation session, whether the user wants to generate the corresponding visual
  assets
- Addition of `content-images` to the **`growth` bundle**

## Non-Goals

- Text overlay / composite images (Sharp + opentype) — excluded; visual text is
  delegated to the user's design toolchain (Canva, Figma, etc.)
- Pre-defined image sets or batch configuration — content and images are dynamic
  per interaction, driven by the briefing
- CI/CD automation — images are generated on-demand by Claude, not in pipelines

## Architecture

Three components:

```
.octopus/content-images.json   ← brand preset (created once per project)
skills/content-images/SKILL.md ← orchestration instructions for Claude
.claude/agents/social-media.md ← Image Asset Protocol section added at end
bundles/growth.yml             ← content-images skill added
```

### Component 1: Brand Preset (`.octopus/content-images.json`)

Created **once per project**, committed to version control. Holds only the
brand context that is constant across all generated images. No image sets,
no hardcoded slugs.

```json
{
  "brand": {
    "name": "Project Name",
    "visual_style": "dark, moody, editorial, cinematic",
    "subjects": "main visual subjects for this brand",
    "negative": "no text, no logos, no watermarks"
  },
  "outputs": {
    "og": "./public/blog/",
    "instagram": "./public/social/"
  }
}
```

**Fields:**

| Field | Required | Description |
|---|---|---|
| `brand.name` | yes | Project name prepended to all prompts |
| `brand.visual_style` | yes | Adjectives describing the desired aesthetic |
| `brand.subjects` | yes | Main subjects/themes of the imagery |
| `brand.negative` | no | Negative constraints (default: "no text, no logos") |
| `outputs.og` | no | Directory for OG/blog images (default: `./public/blog/`) |
| `outputs.instagram` | no | Directory for Instagram images (default: `./public/social/`) |

If the file does not exist, Claude operates in **ad-hoc mode**: collects brand
context interactively from the user before generating.

### Component 2: Skill (`skills/content-images/SKILL.md`)

#### Invocation

```
/octopus:content-images <briefing> [--force]
```

Or invoked from within `social-media` at the end of a content session.

**Arguments:**
- `<briefing>` — conversational description: topic, format, channel, and target
  output filename/slug
- `--force` — regenerate even if the output file already exists

#### Supported Formats

| Format | Dimensions | Use |
|---|---|---|
| `og` | 1200×630 px | Blog post covers, Open Graph tags |
| `instagram` | 1080×1080 px | Instagram feed posts |
| `carousel` | 1080×1080 px × N slides | Instagram carousels (N specified in briefing) |

Claude infers format from the briefing context. User can be explicit:
> "generate an OG image for the article about student dropout"
> "create 5 carousel slides about the benefits of automated billing"

#### Execution Flow

```
1. Read .octopus/content-images.json  →  brand context
   (if absent: ask user for brand context interactively)

2. Parse briefing  →  topic, format, slug, output path

3. Check cache:
   - Does output file already exist at the target path?
   - If YES and no --force → report path, skip generation
   - If NO or --force → proceed

4. Build Gemini prompt:
   "Professional [format] image for [brand.name]. Topic: [topic].
    Style: [brand.visual_style]. Subjects: [brand.subjects]. [brand.negative].
    [format-specific dimension and aspect ratio constraints]."

5. Call image generation API:
   Primary:   Gemini Imagen via @google/genai (requires GEMINI_API_KEY)
   Fallback:  Pollinations.ai  (https://image.pollinations.ai/prompt/<encoded>)
              — free, no key required, lower quality

6. Process image:
   - Resize to target dimensions (sharp)
   - Convert to JPEG: quality=85, progressive=true, mozjpeg=true
   - Save to output path derived from outputs config + slug

7. Return: file path, dimensions, generation method used
```

#### API Key Resolution

The skill reads `GEMINI_API_KEY` using this priority order:

1. `process.env.GEMINI_API_KEY` (already in environment)
2. `.env.octopus` file at the project root — parsed inline via bash

**`.env.octopus` entry required:**
```
GEMINI_API_KEY=your-key-here
```

Claude must never hardcode or print the key. If the key is missing from both
sources, fall back to Pollinations.ai and inform the user.

#### Caching Contract

- Existence check is by **output file path**, not by content or prompt hash
- `--force` skips the check entirely and overwrites
- When skipping, Claude reports: `✓ already exists: <path>` and moves on
- When generating, Claude reports: `✓ generated: <path> (via <provider>)`

### Component 3: Social-Media Agent Update

Add a new section to `.claude/agents/social-media.md` after Phase 4:

#### Image Asset Protocol (Phase 4.5)

After the Approval Gate, before Publish Payload Preparation:

1. List the visual assets implied by the content produced (cover image, carousel
   slides, story frames, etc.)
2. Ask the user explicitly (language-adaptive — match the user's language):
   > "Would you like me to generate the images for this campaign? I can create
   > the visual assets now using the project's brand preset."
3. If the user confirms → apply `octopus:content-images` for each asset,
   passing the campaign briefing as context
4. If the user declines → include a manual asset brief in the output (dimensions,
   format, visual concept for each item)

This keeps the social-media agent responsible for content strategy while
delegating image generation to the dedicated skill.

### Component 4: Bundle Update

Add `content-images` to `bundles/growth.yml`:

```yaml
skills:
  - launch-feature
  - launch-release
  - content-images   # ← new
```

## Setup Guide (for Consumer Projects)

### 1. Install dependencies (if not already present)

```bash
npm install @google/genai sharp
```

### 2. Add API key to `.env.octopus`

```
GEMINI_API_KEY=your-google-genai-api-key
```

Never commit `.env.octopus`. Verify it is in `.gitignore`.

### 3. Create brand preset

```bash
# Create .octopus/content-images.json in your project
{
  "brand": {
    "name": "Your Project",
    "visual_style": "modern, clean, professional",
    "subjects": "describe your main visual subjects",
    "negative": "no text, no logos, no watermarks"
  },
  "outputs": {
    "og": "./public/blog/",
    "instagram": "./public/social/"
  }
}
```

### 4. Use

Ad-hoc:
```
/octopus:content-images create an OG image for the article about automated billing
```

After social-media session, the agent will prompt automatically.

Force regeneration:
```
/octopus:content-images regenerate og-reduzir-evasao --force
```

## Verification

End-to-end test scenario:

1. Create `.octopus/content-images.json` with brand preset in a test project
2. Add `GEMINI_API_KEY` to `.env.octopus`
3. Invoke `/octopus:content-images create an OG image for a blog post about X`
4. Verify: file saved at correct path, dimensions 1200×630, JPEG format
5. Invoke same command again (no --force) → should skip and report existing file
6. Invoke with `--force` → should regenerate and overwrite
7. Run a social-media session → at Phase 4.5, agent should ask about image generation
8. Confirm image generation from within social-media session

**Without Gemini key:**
- Remove `GEMINI_API_KEY` from env
- Verify skill falls back to Pollinations.ai
- Verify user is informed of the fallback

## Files to Create / Modify

| File | Action |
|---|---|
| `skills/content-images/SKILL.md` | Create |
| `.claude/agents/social-media.md` | Add Image Asset Protocol (Phase 4.5) |
| `.opencode/agents/social-media.md` | Same update (keep in sync) |
| `bundles/growth.yml` | Add `content-images` to skills list |
| `docs/roadmap.md` | Add RM entry |
