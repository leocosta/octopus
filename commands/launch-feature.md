---
name: launch-feature
description: (Octopus) Generate a multi-channel launch kit from a completed feature (RM/spec/PR).
---

# /octopus:launch-feature

## Purpose

Turn a completed feature into a versioned, multi-channel launch kit under
`docs/marketing/launches/YYYY-MM-DD-<slug>/` — Instagram, LinkedIn, X thread,
email, landing-page copy, commercial changelog, video script, and optional
images.

## Usage

```
/octopus:launch-feature <ref> [--channels=a,b,c] [--dry-run] [--no-images] [--images-only] [--angle=<label>] [--force]
```

- `<ref>`: `RM-NNN`, spec/research path, or PR (`#123` / URL).

## Instructions

Invoke the `launch-feature` skill (`skills/launch-feature/SKILL.md`).
The skill owns the full workflow: ref resolution, override cascade, template
rendering, optional image generation.

Do not reinterpret the skill here — dispatch to it.
