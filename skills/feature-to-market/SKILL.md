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
