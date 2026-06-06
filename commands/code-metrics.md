---
name: code-metrics
description: (Octopus) Dual-delta read of coverage/complexity/module-size/deps vs. orphan-ref baseline; ratchet+absolute thresholds; LLM curation only on breach.
---

# /octopus:code-metrics

## Purpose

Read how your current branch moves a fixed set of deterministic code metrics
before you open the PR. Two deltas are always reported:

- **vs_baseline** — versus the last-main baseline (trend anchor)
- **vs_main** — versus local `main` HEAD (this-PR impact)

Numbers come from stack-specific tooling (≈0 LLM tokens). A low-cost model is
invoked **only** on a threshold breach.

## Usage

```
/octopus:code-metrics [--stack <csharp|typescript>] [--metric <name>] [--verbose]
```

Invoke the `code-metrics` skill, which runs `octopus code-metrics`. See
`skills/code-metrics/SKILL.md` for the full metric set, threshold config,
dual-delta semantics, adapter details, and writer-Action installation.
