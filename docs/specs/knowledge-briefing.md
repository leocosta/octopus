# Spec: Knowledge Briefing

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo |
| **Status** | Draft |
| **RFC** | N/A |

## Problem Statement

RM-109, the third Cluster 19 engine, built on the RM-106 registry and the RM-107/108 hybrid pattern. A knowledge base only speaks when spoken to: `knowledge-hygiene` and `knowledge-synthesize` answer when invoked, but nothing tells you *what changed* or *what needs you today* on a cadence. For a manager tracking 6+ contexts (the consigliere workspace) or a team's `docs/`+roadmap, the cost of "you didn't know to ask" is real — a blocker recorded yesterday stays invisible until queried.

`knowledge-briefing` generates a summary over a target root **on a cadence**, without the reader formulating a question. `--daily` = what needs attention now; `--weekly` = a rollup of the period's changes. Read-only and grounded (every line cites its source node). The cadence itself is hosted by `/schedule` or `/loop` — the skill is a single run.

See [research](../research/2026-05-31-knowledge-root-operations.md). Strongest targets: the consigliere workspace and `docs/`+roadmap.

## Goals

- Generate a briefing over a target root: `--daily` (attention deltas — what changed / what is overdue / what is newly blocked since the last run) and `--weekly` (a synthesized rollup of the period).
- Detect "since when" robustly across roots (git vs non-git vs a stored watermark).
- Grounded: every briefing line cites the source node it came from; nothing invented.
- Reuse the sibling engines' deterministic signals (`hygiene` deltas, `synthesize` new connections) rather than recomputing — the briefing is a *framing* over existing signals.
- Cadence-host-agnostic: one run per invocation; `/schedule` / `/loop` drive repetition. No scheduler in the skill.

## Non-Goals

- Hygiene / synthesis logic itself — RM-107 / RM-108; the briefing composes their output.
- The consigliere lens (political-risk voice) over the briefing — RM-110.
- A notification/delivery channel (email, Slack) — out of scope; stdout / a written file only.
- Embeddings or summarization models beyond the wrapping skill's judgment.

## Design

### Overview

A deterministic core (`octopus briefing`) computes the change-delta over `octopus kr` and composes the sibling engines (`hygiene`, `synthesize`); a `knowledge-briefing` SKILL.md narrates the grounded human briefing on the cheapest model tier. Same hybrid split as RM-107/108: structure and deltas are deterministic; the narration is the LLM's. Cadence is hosted by `/schedule` / `/loop`, not the skill.

### Detailed Design

**Watermark — per-root, user-scoped.** State lives in `${XDG_CONFIG_HOME:-$HOME/.config}/octopus/briefing-state/<root-id>` — keyed by root id, **never written into a team repo**. `--daily` reads it as the "since", then advances it to now. First run (no watermark) falls back to `--since` or a 7-day default. `--since <window>` overrides for one run without touching the watermark.

**Change-delta — the briefing's unique signal.** A node is "changed since" when its last update — reusing the hygiene cascade (frontmatter `updated:` → git last-commit → mtime) — is newer than the watermark. Emitted as `changed|root|node|<age>`. (v1 lumps new + edited; a git `--diff-filter=A` refinement for "brand new" is a follow-up.)

**Composition — don't recompute.** For the "needs you" section the core runs `octopus hygiene --root <id>` and keeps the `warn`-tier findings (overdue / stale / broken); `--weekly` additionally folds `octopus synthesize` (new connections). Output is re-tagged, not re-derived.

**`--daily` vs `--weekly`.**
- `--daily` → attention list: changed-since-watermark + hygiene warn-tier; advances the watermark.
- `--weekly` → rollup: the period's changes (7-day window or `--since`) handed to the SKILL.md for a narrated summary; does **not** advance the daily watermark.

**Grounding.** Every core line carries its source node; the SKILL.md must cite `(src: <node>)` per line and invent nothing — reusing the RM-088 audit-grounding discipline.

**Output** — the core emits `section|root|node|detail` lines (`changed` / `attention` / `connection`); the SKILL.md renders the grounded briefing.

### Migration / Backward Compatibility

Additive — new `octopus briefing` subcommand and `knowledge-briefing` skill; reuses the RM-106 registry and the RM-107/108 engines. The watermark is per-user state, created on first run; no existing surface changes.

## Implementation Plan

1. **Core scaffold** — `cli/lib/knowledge-briefing.sh` + `cli/lib/briefing.sh` (`octopus briefing`), usage line in `cli/octopus.sh`; flags `--root`/`--daily`/`--weekly`/`--since`.
2. **Watermark** — read/advance per-root state under `${XDG_CONFIG_HOME}/octopus/briefing-state/<id>`; `--since`/default fallback.
3. **Change-delta** — emit `changed|root|node|age` for nodes updated after the watermark (hygiene cascade for last-update).
4. **Compose attention** — fold `octopus hygiene` warn-tier into `attention|...`; `--weekly` folds `octopus synthesize` into `connection|...`.
5. **`--daily` advances watermark; `--weekly` window-only** — wire the two modes.
6. **SKILL.md + command + report template + bundle** — grounded narration wrapper (cheap-tier), structural tests.

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [backend-developer, architect]
**Related ADRs**: [ADR-009 (config scoping)]
**Skills needed**: [adr, doc-design, knowledge-hygiene, knowledge-synthesize, audit-grounding]
**Bundle**: introduces the `knowledge-briefing` skill — same bundle as the sibling engines (`quality`, or a future `knowledge-ops`); settle in design.

**Constraints**:
- Pure bash, no external dependency; all filesystem access via `octopus kr` and the sibling engines.
- Read-only by default; never invents — grounded to source nodes.
- No scheduler in the skill — cadence is hosted by `/schedule` / `/loop`.
- Language-neutral core (per RM-108): no hardcoded natural-language tokens; narration is the LLM's job.

## Testing Strategy

- Behavioral fixtures: a node updated after a written watermark → `changed`; an untouched node → absent. `--daily` advances the watermark (a second run shows nothing). `--since` overrides without advancing. First run with no watermark falls back to the default window.
- Watermark isolation: state path is honored via an env override so tests never touch the real user config; nothing is written into the fixture repo.
- Composition: with a stale/overdue node, `--daily` output carries an `attention|` line sourced from `octopus hygiene`.
- Structural assertions on `skills/knowledge-briefing/SKILL.md` (frontmatter, invocation, daily/weekly, grounding `(src:`), mirroring `test_knowledge_hygiene.sh`.

## Risks

- **Delta reliability.** mtime/git/watermark each fail on some root; a wrong "since" silently drops or floods items. Mitigation: an explicit cascade with a stored watermark fallback, surfaced in the design.
- **Recomputation cost.** Re-running hygiene/synthesize per briefing on a large root is expensive on a cadence. Mitigation: compose their output, cache where cheap.

## Changelog

- **2026-05-31** — Initial draft (stub pre-filled from Cluster 19 research).
- **2026-05-31** — Design session completed. Settled: per-root user-scoped watermark (+ `--since` fallback), change-delta as the core's unique signal, composition of `hygiene`/`synthesize` (no recompute), `--daily` advances the watermark while `--weekly` is window-only, grounded narration on the cheap tier. Detailed Design, Implementation Plan, Testing filled.
