---
name: launch-feature
description: Generate a multi-channel launch kit from a completed feature (RM/spec/PR).
---

---
description: Generate a multi-channel launch kit from a completed feature (RM/spec/PR).
agent: code
---

# /octopus:feature-to-market

## Purpose

Turn a completed feature into a versioned, multi-channel launch kit under
`docs/marketing/launches/YYYY-MM-DD-<slug>/` — Instagram, LinkedIn, X thread,
email, landing-page copy, commercial changelog, video script, and optional
images.

## Usage

```
/octopus:feature-to-market <ref> [--channels=a,b,c] [--dry-run] [--no-images] [--images-only] [--angle=<label>] [--force]
```

- `<ref>`: `RM-NNN`, spec/research path, or PR (`#123` / URL).

## Instructions

Invoke the `feature-to-market` skill (`skills/feature-to-market/SKILL.md`).
The skill owns the full workflow: ref resolution, override cascade, template
rendering, optional image generation.

Do not reinterpret the skill here — dispatch to it.
