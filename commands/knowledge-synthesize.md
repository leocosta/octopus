---
name: knowledge-synthesize
description: (Octopus) Surface cross-node connections in a knowledge root — shared-target, co-mention, and forgotten-but-relevant; judge contradictions; --fix seeds missing links.
---

# /octopus:knowledge-synthesize

## Purpose

Surface connections that cross the nodes of a knowledge root (`docs/`, the
standards set, auto-memory, the consigliere workspace). The deterministic
candidate-finding runs in the `octopus synthesize` core over `octopus kr`; the
skill judges relevance and contradiction and seeds links.

## Usage

```
/octopus:knowledge-synthesize [--root <id>] [--node <path>] [--fix]
```

Invoke the `knowledge-synthesize` skill, which wraps `octopus synthesize`. See
`skills/knowledge-synthesize/SKILL.md` for the signals, contradiction judgment,
and fix semantics.
