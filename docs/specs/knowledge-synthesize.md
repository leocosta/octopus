# Spec: Knowledge Synthesize

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo |
| **Status** | Draft |
| **RFC** | N/A |

## Problem Statement

RM-108, the second Cluster 19 engine, built on the RM-106 registry and consistent with the RM-107 hybrid pattern. A knowledge base's value is the IA *traversing* it and surfacing links manual recall would miss — but every root is a silo today. A blocker recorded in two contexts, a spec that contradicts an ADR, a forgotten-but-relevant past note for a current question: none of these surface unless you already suspect them and ask. `knowledge-synthesize` surfaces **connections that cross nodes** of a root, and seeds/repairs the link convention where it is missing.

Strongest targets: the auto-memory (already `[[ ]]`-linked, built for this) and `docs/` (specs vs ADRs). Reuses `octopus kr` (RM-106) for nodes/links and follows the RM-107 hybrid split — deterministic candidate-finding in a core, fuzzy relevance/contradiction judgment in a SKILL.md.

See [research](../research/2026-05-31-knowledge-root-operations.md).

## Goals

- Surface cross-node connections of a root: **shared targets** (two nodes linking the same third), **co-mentioned entities** (the same `[[mention]]`/term recurring across nodes with no home node), and **candidate contradictions** (a node asserting something a linked authority — e.g. an ADR — negates).
- A "forgotten-but-relevant" lookup: given a node or query, surface past nodes that are topically related but unlinked.
- Seed/repair the link convention where missing (suggest a `[[ ]]`/relative link the author likely meant).
- Hybrid: a deterministic core finds candidates over `octopus kr`; the SKILL.md judges relevance and real-vs-spurious contradiction.

## Non-Goals

- Staleness / orphan / archive hygiene — that is `knowledge-hygiene` (RM-107).
- Proactive cadence summaries — that is `knowledge-briefing` (RM-109).
- The consigliere lens over the output — RM-110.
- Semantic embeddings / a vector index — start with lexical/link-graph signals (YAGNI until they prove insufficient).

## Design

### Overview

A deterministic core (`octopus synthesize`) computes ranked connection candidates over `octopus kr`; a `knowledge-synthesize` SKILL.md judges relevance, real-vs-spurious contradiction, and which links to seed. Same hybrid split as RM-107: structure and ranking are deterministic and testable; the fuzzy verdict is the LLM's.

### Detailed Design

**Core signals** — each emitted as `kind|root|a|b|signal|score`:

1. **shared-target** — a node pair whose `kr links` sets intersect (both link the same third node). `score` = intersection size; `signal` = the shared target. "These two relate via X."
2. **co-mention** — an entity appearing in ≥2 nodes with **no node of its own**. `score` = node count. A recurring topic with no home — framed as the connection across the nodes that mention it (overlaps RM-107 `--gaps`, different framing).
3. **relevant** (with `--node` or a query) — other nodes ranked by shared-rare-term overlap (Jaccard over entity sets). The "forgotten-but-relevant" lookup.

**Entity extraction** (`ks_entities <file>`): `[[mentions]]` where the convention has them; elsewhere a light heuristic — Capitalized Multiword phrases + `` `code` `` spans — filtered by a stopword list and a min length. Root-agnostic; richer on wikilinked roots (memory), still useful on `docs/`.

**Contradiction — not in the core.** The core emits a node plus the authorities it links (e.g. ADRs); the SKILL.md judges whether the node contradicts them. The deterministic layer stays precise.

**Invocation** `octopus synthesize [--root <id>] [--node <path>] [--fix]`:

- no `--node` → cross-node connections across the root (shared-target pairs + co-mentioned entities), ranked, top-N capped (default 10).
- `--node <path>` → forgotten-but-relevant ranking for that node + its shared-target neighbours.
- `--fix` → seed a missing link only when a single high-confidence target exists (e.g. a co-mention that exactly matches one node's title); otherwise report-only.

**Output** — ranked lines plus a tier (`strong` / `weak`); the SKILL.md renders the human report and applies judgment.

**Reuse:** `octopus kr` (nodes / links / meta); the `knowledge-hygiene` tooling shape (core + `octopus <cmd>` + SKILL.md + bundle). New: the `ks_entities` extractor.

### Migration / Backward Compatibility

Additive — new `octopus synthesize` subcommand and `knowledge-synthesize` skill; no existing surface changes. Reuses the RM-106 registry and the RM-107 tooling shape.

## Implementation Plan

1. **Core scaffold** — `cli/lib/knowledge-synthesize.sh` + `cli/lib/synthesize.sh` (`octopus synthesize`), usage line in `cli/octopus.sh`; emit an empty ranked report over the target roots.
2. **Entity extractor** — `ks_entities <file>`: `[[mentions]]` + Capitalized-multiword + `` `code` `` spans, stopword/min-length filtered.
3. **shared-target signal** — node-pair link-set intersection over `kr links`.
4. **co-mention signal** — entities recurring across ≥2 nodes with no own node.
5. **relevant signal** — `--node`/query lexical-overlap (Jaccard over entity sets), top-N capped.
6. **`--fix`** — seed a single high-confidence missing link (else report-only).
7. **SKILL.md + command + report template + bundle** — wrapper for relevance/contradiction judgment; structural tests.

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [backend-developer, architect]
**Related ADRs**: [ADR-009 (config scoping), ADR-010 (hygiene boundary — sibling engine)]
**Skills needed**: [adr, doc-design]
**Bundle**: introduces the `knowledge-synthesize` skill — adopt into the same bundle as `knowledge-hygiene` (`quality`, or a future `knowledge-ops`); settle in design.

**Constraints**:
- Pure bash, no external dependency; all filesystem access via `octopus kr`.
- Lexical/link-graph signals only in v1 — no embeddings.
- Follow the RM-107 hybrid split (deterministic core + SKILL.md judgment).

## Testing Strategy

- Behavioral fixtures over a synthetic root: two nodes linking a shared third (→ shared-target); an entity in 3 nodes with no home (→ co-mention); a focus node sharing rare terms with one of several others (→ `--node` ranks it top). Assert the ranked lines and tiers.
- `ks_entities`: `[[mention]]` extraction; Capitalized-multiword + `` `code` `` on a non-wikilinked node; stopwords filtered.
- `--fix`: seeds a link only on an exact single-target co-mention; report-only otherwise (assert no write).
- Structural assertions on `skills/knowledge-synthesize/SKILL.md` (frontmatter, invocation, signals, contradiction-judgment section), mirroring `test_knowledge_hygiene.sh`.

## Risks

- **Signal precision.** Lexical co-mention is noisy; without ranking it floods the user. Mitigation: confidence tiers + a top-N cap, surfaced in the design.
- **Contradiction false positives.** Negation-token heuristics over-fire; keep the core's role to *candidate* surfacing and leave the verdict to the SKILL.md.

## Changelog

- **2026-05-31** — Initial draft (stub pre-filled from Cluster 19 research).
- **2026-05-31** — Design session completed. Settled: hybrid (core + SKILL.md) per RM-107; v1 signals = shared-target + co-mention + lexical-overlap; entity extraction = wikilink + light heuristic; contradiction judged by the SKILL.md, not the core. Detailed Design, Implementation Plan, Testing filled.
