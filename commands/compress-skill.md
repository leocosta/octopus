---
name: compress-skill
description: Shrink a SKILL.md — deterministic cleanup + optional LLM rewrite — with invariants on frontmatter, headings, code blocks, and test anchors.
---

---
description: Shrink a SKILL.md — deterministic cleanup + optional LLM rewrite — with invariants on frontmatter, headings, code blocks, and test anchors.
agent: code
---

# /octopus:compress-skill

## Purpose

Reduce the size of a `SKILL.md` file by ~25% without changing its
meaning. Dry-run by default; `--apply` writes the result. Preserves
frontmatter, headings, code blocks, and every literal string the
skill's test file greps for.

## Usage

```
/octopus:compress-skill <skill-name> [--apply] [--target=25] [--max-loss=5] [--heuristics-only]
```

## Instructions

Invoke the `compress-skill` skill (`skills/compress-skill/SKILL.md`).
The skill owns the full workflow: anchor extraction from tests,
Step-1 deterministic cleanup, Step-2 LLM rewrite, invariant
enforcement, diff rendering, and the `--apply` write.

Do not reinterpret the skill here — dispatch to it.
