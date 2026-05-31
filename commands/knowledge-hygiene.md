---
name: knowledge-hygiene
description: (Octopus) Audit a knowledge root for staleness, broken links, orphans, and archive drift; --gaps for coverage, --fix for reversible remedies.
---

# /octopus:knowledge-hygiene

## Purpose

Audit any registered knowledge root (`docs/`, the standards set, auto-memory,
the consigliere workspace) for decay. The deterministic checks run in the
`octopus hygiene` core over the `octopus kr` registry; the skill adds the
`--gaps` judgment and `--fix` confirmation.

## Usage

```
/octopus:knowledge-hygiene [--root <id>] [--gaps] [--fix] [--write-report]
```

Invoke the `knowledge-hygiene` skill, which wraps `octopus hygiene`. See
`skills/knowledge-hygiene/SKILL.md` for the checks, gaps mode, fix semantics,
and per-root configuration.
