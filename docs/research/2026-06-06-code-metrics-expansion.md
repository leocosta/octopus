# Research: code-metrics-expansion

**Date:** 2026-06-06
**Trigger:** Interview (`/octopus:interview`) — "what else could I add to the
deterministic metric set of `code-metrics`?". The v1 (RM-147 / Cluster 25,
#175) shipped four metrics (coverage, complexity, module_size,
dependency_cycles); this session scoped the next wave.

## Context

`code-metrics` (formerly `quality-metrics`, renamed in #186/#188 and folded into
the `quality` bundle) gives a PR author a local, non-blocking, dual-delta read
(`vs_baseline` from the `octopus/code-metrics` orphan ref, `vs_main` from local
`main`). Numbers are computed by deterministic stack tooling (≈0 LLM tokens); a
Haiku-class model is invoked **only** on a threshold breach to explain and
suggest a fix. v1 ships C# and TypeScript adapters.

Cluster 25 explicitly deferred mutation testing, AI/agent attribution, a
cross-repo manager dashboard, and a blocking gate. This research does **not**
revisit those — it expands the *deterministic metric catalog* within the
existing contract.

The interview anchored three pain points across 6+ repos:

- **B1 — decay:** code degrades over time.
- **B2 — practices/readability:** the team does not apply best practices and
  does not care about readability.
- **B3 — load risk:** change risk in high-traffic apps is never assessed.

## Analysis

The defining decision was the **deterministic vs. non-deterministic** trade-off,
resolved in favour of deterministic across every branch:

- **B2 (readability)** was the branch where an LLM-scored readability grade was
  most tempting. It was **discarded**: non-determinism (same diff → varying
  score), per-PR token cost (not just on breach), and gaming/dispute ("why a 6
  and not an 8?") outweigh the upside. B2 ships as objective counters the team
  cannot contest.
- **B3 (load risk)** forked into a real load test (p95/throughput under load)
  vs. a cheap static proxy of performance risk. The real load test was
  **discarded** from this scope: it needs a running app, a provisioned
  environment, and minutes — it cannot be computed from a static diff and breaks
  the "PR-time, ≈0-cost" contract. Only the static proxy survives, and even that
  is deferred to v3 for effort/false-positive reasons.
- **B1 (decay)** resolved to two faithful images: **hotspots** (files that
  change often *and* are complex — churn × complexity, needs git history) and
  **debt accumulation** (markers that rise over time). The third image,
  "erosion of an already-measured `vs_baseline`", is a *visibility* problem, not
  a missing-metric problem — set aside.

Candidates do not cost the same to build, which drove the v2/v3 split
(leverage-by-effort chosen over attack-the-deepest-pain-first):

| Candidate | Build effort | False-positive risk | Branch | Wave |
|---|---|---|---|---|
| Debt markers (grep TODO/deprecated/disable) | trivial | ~zero | B1 | v2 |
| Readability counters (nesting/params/magic#/lint density) | low (lizard covers part) | low | B2 | v2 |
| Doc coverage | low | low | B2 | v2 |
| Hotspots (churn × complexity) | medium (**new capability**: read git log) | low | B1 | v3 |
| Perf-risk proxy (hot path / O(n²) / query-in-loop / hot-path alloc) | high (per-language AST heuristic) | **high** | B3 | v3 |

All survivors stay inside the existing contract: deterministic, ≈0-cost in the
common case, LLM only on breach, dual-delta preserved, configurable per-layer in
`.octopus.yml`, C#+TS. New metric fields land as extra keys in the orphan-ref
`baseline.json`, so cross-repo aggregation is enabled *at the storage level* —
but exercising it (a manager dashboard) is **not** an entry-criterion for this
work.

### Open questions (carry into the RM-148 spec)

- **Ratchet-only vs. absolute threshold** per new metric. A legacy repo with
  5,000 existing TODOs must not be born "red" — the working assumption is
  ratchet-only by default, with absolute floors/ceilings opt-in (consistent with
  the existing `.octopus.yml` precedence, ADR-005/RM-069).
- **Dead-code: marked vs. reachability.** v2 is expected to count only
  *marked* dead code (grep) — reachability analysis is per-language and pushes
  the item out of the cheap/low-risk band.
- **Tooling beyond `lizard`** for magic-numbers and doc-coverage — define the
  per-stack adapter (C#/TS) for the counters `lizard` does not already provide.

## Identified Items

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| RM-148 | v2 metric pack: debt markers + readability counters + doc coverage | 🔴 High | medium |
| RM-149 | v3 hotspots: churn × complexity (git-history capability) | 🟡 Medium | medium |
| RM-150 | v3 perf-proxy: static risk heuristic for high-traffic paths | 🟡 Medium | high |

## Discarded Items

| Title | Reason |
|-------|--------|
| LLM-scored readability grade | Non-deterministic, per-PR token cost (not just on breach), gaming/dispute. The whole expansion was kept deterministic. |
| Real load test (p95/throughput under load) | Needs a running app + provisioned env + minutes; cannot compute from a static diff; breaks the PR-time ≈0-cost contract. Belongs to a separate CI gate, not `code-metrics`. |
| `vs_baseline` erosion metric | Not a missing metric — the trend delta already exists; it is a visibility/adoption problem. |
| Cross-repo manager dashboard | Out of scope (already deferred by Cluster 25). New metric fields enable it at the storage level; building the readout is a separate, larger deliverable. |
| Dead-code by reachability (v2) | Per-language reachability analysis is medium-high effort + medium false-positive; v2 counts only *marked* dead code. Folds into the RM-150 perf/AST wave if pursued. |
