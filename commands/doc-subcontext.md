---
name: doc-subcontext
description: (Octopus) Create a scoped CLAUDE.md at a subdirectory — captures conventions unique to one module without duplicating the parent.
---

# /octopus:doc-subcontext

## Purpose

The `doc-subcontext` skill defines the discipline for writing a
per-subdirectory `CLAUDE.md` in a large monorepo. This slash command
drives it explicitly for one path the user names.

## Usage

```
/octopus:doc-subcontext <subdirectory path>
```

Example: `/octopus:doc-subcontext api/payments`

## Instructions

Invoke the `doc-subcontext` skill (`skills/doc-subcontext/SKILL.md`).
The skill owns the parent-chain reading, the one-question-at-a-time
interview, the lean target (50–100 lines), and the cross-reference-not-
duplication rule — do not reinterpret here.

If no root `CLAUDE.md` exists in the repo, refuse and direct the user
to run `octopus update` first. A subcontext is only meaningful **on
top of** a root context.
