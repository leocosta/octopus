---
name: content-images
description: >
  Generate brand-consistent images for blog covers, Instagram feed posts,
  and carousels using AI (Gemini Imagen with Pollinations.ai fallback).
  Reads brand context from .octopus/content-images.json; GEMINI_API_KEY
  from .env.octopus. Caches by output file path — skips existing files
  unless --force is passed.
triggers:
  paths: []
  keywords:
    - "og image"
    - "blog cover"
    - "instagram image"
    - "carousel"
    - "content image"
    - "imagem"
    - "capa"
    - "carrossel"
  tools: []
---

# Content Images Protocol

## Overview

This skill generates brand-consistent images for content campaigns. It
resolves the brand preset, infers the output format from the briefing,
checks the file cache, and generates via Gemini Imagen (or Pollinations.ai
when no key is available). All content and prompts are dynamic per
interaction — there are no hardcoded image sets.

The skill composes with the `social-media` agent: after the social-media
agent finishes Phase 4 (Approval Gate), it asks whether to generate the
visual assets and then dispatches to this skill with the campaign briefing.

## Invocation

```
/octopus:content-images <briefing> [--force]
```

**Arguments:**
- `<briefing>` — conversational description of the image needed: topic,
  channel, intended filename or slug (e.g. "create an OG image for the
  article about student dropout, slug og-evasao")
- `--force` — regenerate even if the output file already exists

## Execution Flow

Execute in order for each image in the briefing:

### Step 1 — Load brand preset

```bash
cat .octopus/content-images.json 2>/dev/null
```

If the file exists, extract:
- `brand.name` — project name
- `brand.visual_style` — aesthetic descriptors
- `brand.subjects` — main visual subjects
- `brand.negative` — negative constraints (default: `"no text, no logos, no watermarks"`)
- `outputs.og` — output dir for OG images (default: `./public/blog/`)
- `outputs.instagram` — output dir for Instagram images (default: `./public/social/`)

If the file does not exist, ask the user for brand context interactively
before proceeding.

### Step 2 — Parse briefing

From the briefing, determine:
- **topic** — what the image should depict
- **format** — `og`, `instagram`, or `carousel` (see Format Inference below)
- **slug** — filename without extension (e.g. `og-evasao-alunos`)
- **slide count** — for carousel only (infer from briefing; default: 5)

### Step 3 — Resolve output path

```
og         →  <outputs.og>/<slug>.jpg
instagram  →  <outputs.instagram>/<slug>.jpg
carousel   →  <outputs.instagram>/<slug>/slide-NN.jpg  (for each slide)
```

### Step 4 — Cache check

```bash
test -f <output-path>
```

- If file exists and `--force` is **not** set: print `✓ already exists: <path>` and skip.
- If file does not exist or `--force` is set: proceed to generation.

### Step 5 — Resolve API key

```bash
# Try environment first, then .env.octopus
echo "${GEMINI_API_KEY:-$(grep '^GEMINI_API_KEY=' .env.octopus 2>/dev/null | cut -d= -f2-)}"
```

- If a non-empty key is found → use Gemini Imagen
- If empty → fall back to Pollinations.ai; inform the user once

### Step 6 — Build prompt

```
Professional <format-description> for <brand.name>.
Topic: <topic>.
Style: <brand.visual_style>.
Subjects: <brand.subjects>.
<brand.negative>.
<format-constraints>
```

Format-specific constraints appended:
- `og` → `"16:9 widescreen aspect ratio, 1200×630 pixels, blog cover composition."`
- `instagram` → `"Square 1:1 aspect ratio, 1080×1080 pixels, Instagram feed composition."`
- `carousel` → `"Square 1:1 aspect ratio, 1080×1080 pixels, slide <N> of <total>: <slide-topic>."`

### Step 7 — Generate image

**With Gemini key:**

```javascript
// node -e inline script
const { GoogleGenAI } = require('@google/genai');
const fs = require('fs');

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
const response = await ai.models.generateImages({
  model: 'imagen-3.0-generate-002',
  prompt: '<prompt>',
  config: { numberOfImages: 1, aspectRatio: '<ratio>' },
});
const base64 = response.generatedImages[0].image.imageBytes;
fs.writeFileSync('<tmp-path>.png', Buffer.from(base64, 'base64'));
```

Aspect ratio values: `16:9` for OG, `1:1` for Instagram/carousel.

**Without Gemini key (Pollinations.ai fallback):**

```bash
curl -sL "https://image.pollinations.ai/prompt/<url-encoded-prompt>?width=<w>&height=<h>&nologo=true" \
  -o <tmp-path>.png
```

Width/height by format: 1200×630 (OG), 1080×1080 (Instagram/carousel).

### Step 8 — Process and save

```javascript
// node -e inline script using sharp
const sharp = require('sharp');
await sharp('<tmp-path>.png')
  .resize(<width>, <height>)
  .jpeg({ quality: 85, progressive: true, mozjpeg: true })
  .toFile('<output-path>');
fs.unlinkSync('<tmp-path>.png');
```

If `sharp` is not installed, save the PNG directly to the output path
and inform the user that JPEG conversion requires `npm install sharp`.

### Step 9 — Report

```
✓ generated: <output-path>  (via gemini | pollinations)
```

For carousels, report each slide on its own line.

## Format Inference

Infer the output format from these signals (first match wins):

| Signal in briefing | Format |
|---|---|
| "blog", "artigo", "post", "og", "open graph", "capa do post" | `og` |
| "carrossel", "carousel", "slides", "série de" | `carousel` |
| "instagram", "feed", "square", "quadrado", "post ig" | `instagram` |
| none of the above | ask the user to clarify |

## Supported Formats

| Format | Dimensions | Use |
|---|---|---|
| `og` | 1200 × 630 px | Blog covers, Open Graph meta tags |
| `instagram` | 1080 × 1080 px | Instagram feed posts |
| `carousel` | 1080 × 1080 px × N | Instagram carousels (N slides) |

## API Key Setup

`GEMINI_API_KEY` is read using this priority order:

1. `$GEMINI_API_KEY` environment variable (already exported in shell)
2. `.env.octopus` file at the project root

**Required `.env.octopus` entry:**
```
GEMINI_API_KEY=your-google-ai-studio-key
```

Never print or log the key value. If both sources are empty, fall back to
Pollinations.ai and report: `⚠ GEMINI_API_KEY not found — using Pollinations.ai (lower quality).`

## Brand Preset Setup

Create `.octopus/content-images.json` once per project and commit it:

```json
{
  "brand": {
    "name": "Your Project Name",
    "visual_style": "dark, moody, editorial, cinematic",
    "subjects": "describe the main visual subjects of your brand",
    "negative": "no text, no logos, no watermarks"
  },
  "outputs": {
    "og": "./public/blog/",
    "instagram": "./public/social/"
  }
}
```

## Dependencies

Ensure these npm packages are installed in the project:

```bash
npm install @google/genai sharp
```

`@google/genai` is required for Gemini. `sharp` is required for JPEG
conversion and resizing. Both are optional if using Pollinations.ai
and PNG output, but strongly recommended.

## Examples

```
/octopus:content-images create an OG image for the article about reducing student dropout, slug og-evasao-alunos

/octopus:content-images generate 5 Instagram carousel slides about the benefits of automated billing for martial arts academies

/octopus:content-images regenerate the feed post for the summer campaign --force
```
