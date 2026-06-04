---
name: knowledge-briefing
description: >
  Proactive cadence summary over a knowledge root — 'what changed / what needs
  you today' without being asked. Deterministic core (octopus briefing, over
  the octopus kr registry) computes the change-delta since a per-root
  watermark and composes octopus hygiene + synthesize; this skill narrates it,
  grounded to source nodes, on the cheapest tier.
triggers:
  paths: ["docs/**", "knowledge/**", "CONTEXT.md"]
  keywords: ["briefing", "daily", "weekly", "what changed", "what's new"]
  tools: []
---

# /octopus:knowledge-briefing

## Purpose

A knowledge base only speaks when spoken to. `hygiene` and `synthesize` answer
when invoked; this skill *comes to you* on a cadence with what changed and what
needs attention — the blocker recorded yesterday you didn't know to ask about.

The change-delta and composition are deterministic in the `octopus briefing`
core. This skill turns its lines into a readable, grounded briefing.

## Invocation

```
/octopus:knowledge-briefing [--root <id>] [--daily|--weekly] [--since <window>]
```

- `--root <id>` — one root (e.g. `docs`, `memory`, `consigliere`); default: every resolved root.
- `--daily` — attention briefing; advances the per-root watermark (default mode).
- `--weekly` — a narrated rollup over a 7-day window; does **not** advance the watermark.
- `--since <window>` — override the window for one run (e.g. `"3 days"`), without touching the watermark.

Run the core directly with `octopus briefing [--root <id>] [--daily|--weekly] [--since <window>]`.

## Sections

The core emits `section|root|node|detail`:

- **changed** — a node updated since the last briefing (the watermark).
- **attention** — a `knowledge-hygiene` warn-tier finding (overdue / stale / broken).
- **connection** — (weekly) a `knowledge-synthesize` cross-node candidate.

## Grounding

Every line of the briefing **must cite its source** as `(src: <node>)` and invent nothing — the core already carries the node for each line; never add a claim that no line supports. This reuses the audit-grounding discipline: a briefing that can't be traced to a node is not shipped.

## Narration runs on the cheapest model tier

The costly structural work already happened for free in bash. Turning the core's lines into prose is light work — run it on the **cheapest / fastest model** (Claude: `--model haiku`; other assistants: their cheapest tier). Do not spend a frontier model summarizing a delta list.

## Cadence

This skill is one run. Repetition is hosted by `/schedule` (a morning `--daily`) or `/loop` — not by the skill. The watermark makes each run pick up exactly where the last left off.
