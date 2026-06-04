# Spec: quality-metrics

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-06-04 |
| **Author** | Leonardo |
| **Status** | Draft — ready-for-agent |
| **RFC** | N/A |
| **Roadmap** | RM-147 (Cluster 25 — Code-quality metrics / health tracking) |

## Problem

Code-quality signals — test coverage, cyclomatic complexity, module size, and
dependency structure — degrade quietly across a fleet of repos, and the author
who introduces a regression is the last to know. The motivating worry is the
rising share of code authored by AI harnesses, but the need is broader: **any**
new PR can erode quality, and there is no cheap, autonomous way for the author
to see how their change moves these metrics *before* they open the PR. The
measurement must be near-free in the common case (nothing regressed) and must
not depend on a human reading a dashboard.

## Solution

A `/octopus:quality-metrics` capability that gives the PR author a local,
non-blocking read of how their change moves a fixed set of deterministic
quality metrics. Numbers are always computed cheaply by stack-specific tooling
(no LLM); a low-cost model is invoked **only** when a metric crosses its
threshold, to explain the regression and suggest a fix. A per-merge baseline is
maintained on a dedicated git ref by a single automated writer, so the trend is
always fresh, no PR branch ever conflicts on it, and no protected branch is ever
pushed to. The "AI vs. human" framing is treated as motivation only — every PR
is measured identically, regardless of author.

## User Stories

- As a **PR author**, I run `/octopus:quality-metrics` locally before opening a
  PR and see a **dual delta** — one figure versus the last-main baseline (the
  trend anchor) and one versus my local `main` HEAD (what *this* PR actually
  changed) — at **zero token cost** when nothing regressed.
- As a **PR author whose change regresses a metric past its threshold**, and
  only then, I receive a low-cost LLM reading that explains *why* the metric
  moved (e.g. a function that became a god-function) and suggests a concrete fix.
- As an **author working in a legacy repo**, the ratchet-against-baseline
  default means I am never flagged for pre-existing debt — only for making a
  metric worse than the current main.
- As a **team that wants to pull a repo upward**, we set absolute targets per
  metric (e.g. coverage ≥ 80%) in the repo config, layered on top of the ratchet
  default.
- As a **maintainer**, after a squash-merge to `main` the baseline updates
  automatically, with **no PR-branch conflict** on the metrics store and
  **without any push to `main` or `release/*`**.
- As a **C# repo** or a **TypeScript repo**, stack detection selects the correct
  adapter so the same command and the same metric contract work across both.
- As a **Tech Manager** (future, out of v1), I can read the per-repo metrics ref
  across the fleet to assemble a cross-repo trend — the v1 data shape must not
  foreclose this.

## Implementation Decisions

1. **Actor & gesture.** The primary actor is the PR author at PR-open time. The
   gesture is a **local command**, non-blocking, full autonomy — a signal, never
   a gate. No per-PR CI job is required for the author's read.
2. **Hybrid output, threshold-gated LLM.** Deterministic numbers are always
   produced by tooling (≈0 tokens). LLM interpretation fires **only** on a
   threshold breach, on a low-cost (Haiku-class) model of the harness. Token cost
   in the common case is ≈ zero; it scales with diff size only when something
   regresses.
3. **Dual delta.** The command reports two deltas: (a) versus the last-main
   baseline = trend anchor; (b) versus local `main` HEAD = this-PR impact. This
   separates the two halves of the goal — "track over time" and "per-PR impact" —
   that would otherwise be conflated in a single number.
4. **History store — dedicated orphan ref.** The metrics time-series lives on a
   dedicated, non-protected git ref (`octopus/quality-metrics`). It is *in-repo*
   (no external infrastructure) but **not** on the protected `main`/`release/*`
   tree. Chosen over release-asset storage because per-release cadence left the
   baseline too stale between releases.
5. **Reader/writer separation.** The PR command only **reads** the ref
   (`git fetch`) — PR branches never write the metrics store, so it cannot
   conflict by construction. The baseline is written at exactly one serialized
   point.
6. **Writer — Action reacting to `push:main`.** A GitHub Action triggered on
   `push` to `main` recomputes full-repo metrics on the merged commit and writes
   the orphan ref. Because the repo uses **squash-merge**, main is serialized →
   a single writer, no concurrency, conflict-free. The Action *reacts to* the
   merge event; it never pushes to the protected branch itself. (Relates to the
   fleet-merge policy, ADR-004.)
7. **Hybrid thresholds.** Ratchet-against-baseline by default (zero config,
   works out-of-the-box, legacy does not start "red" — a change simply may not
   regress), with optional absolute targets per metric set per repo. Config
   lives in the existing `.octopus.yml` surface, following the established
   config-precedence model (workspace → personal → project; cf. ADR-005,
   RM-069), so no new storage is introduced.
8. **Pluggable stack adapters.** A stack-agnostic metric contract is implemented
   per stack by an adapter, selected via the existing stack-detection mechanism
   (the `feat/stack-aware-setup` machinery). v1 ships **C#** and **TypeScript**
   adapters. The architecture is born stack-agnostic; further stacks are later
   ports.
9. **v1 metric set.** Coverage, cyclomatic complexity, module size, and
   dependency structure (cycle/graph detection only — no architecture-layering
   judgment yet), all on the per-merge pulse.
10. **Packaging.** A new bundle `quality-metrics`, sibling to `quality-audits`
    and `quality-signals` (the existing `quality` bundle is the audits/gates
    axis; this is the measurement/trend axis). The bundle carries the
    orchestration **skill** and the **writer-Action template** (installed
    per-repo). The **adapters** ship inside the `stack-csharp` and
    `stack-typescript` bundles, consistent with how those bundles already carry
    stack rules/skills. The command is `/octopus:quality-metrics`.

## Manifest surface

How the capability is selected and configured in `.octopus.yml`. Two distinct
mechanisms — do not conflate them.

### Selection (already-supported syntax)

Bundle and profile selection goes through the existing flat bundle parser
(`parse_octopus_yml` in `setup.sh`) and `expand_bundles`. No new parsing:

```yaml
bundles:
  - quality-metrics      # this capability: skill + writer-Action template
  - stack-csharp         # carries the C# adapter (sibling: stack-typescript)
  - db-mssql

exclude:
  - quality-metrics-deps # opt out of one metric in this repo (RM-144 _apply_excludes)
```

The `quality-metrics` bundle is the measurement axis (sibling to
`quality-audits`/`quality-signals`); adapters ship inside the `stack-*` bundles
(decision 10). `exclude:` drops an individual member after expansion.

### Threshold config (feature-owned reader — NOT the central parser)

Thresholds are **not** parsed by `parse_octopus_yml` (which is flat and only
handles `skills/roles/rules/mcp/bundles/exclude`). They follow the established
per-feature precedent: `knowledge_roots:` (RM-106), whose reader
`kr_override`/`kr_field` in `cli/lib/knowledge-root.sh` reads a **2-space nested**
block with **scalar** fields (the "scalar contract" — comma-separated for lists,
never inline-map flow style). The implementing agent should clone that reader as
`qm_override`/`qm_field` in `cli/lib/quality-metrics.sh`; it must not touch
`parse_octopus_yml`.

Block shape (same in every layer; fields are independent):

```yaml
quality_metrics:
  coverage:
    min: 80
  complexity:
    max: 10            # cyclomatic, per function
  module_size:
    max: 400           # lines per module
  dependencies:
    cycles_allowed: 0
```

A field absent from **all** layers falls back to the skill default = **ratchet
only** (a change may not regress versus baseline; no absolute floor/ceiling).
v1 fields: `coverage.min`, `complexity.max`, `module_size.max`,
`dependencies.cycles_allowed`.

### Precedence — three layers, resolved per field

| Layer | File | Scope |
|---|---|---|
| Workspace | `$OCTOPUS_WORKSPACE_PATH/.octopus.yml` (shared standards repo named by the `workspace:` key) | whole team |
| Personal | `${XDG_CONFIG_HOME:-$HOME/.config}/octopus/.octopus.yml` | all of one developer's repos, local only |
| Project | `<repo>/.octopus.yml` | this repo, committed |

**Resolution order (decision): `default < workspace < personal < project` —
project wins.** This mirrors the *rules* precedence (RM-067/068/069: project >
personal > workspace), where the committed repo state is authoritative — the
right call for a quality contract. It is the **opposite** of `kr_field`'s order,
which lets the user (personal) layer override project. Cloning `kr_field`
verbatim would invert this; the agent must apply project **last**.

Resolution is **per field**, not per block: a layer that sets only
`complexity.max` leaves the other fields to lower-precedence layers.

**Workspace-layer config is new work.** `kr_field` today reads only two files
(project `<repo>/.octopus.yml` + personal `~/.config/octopus/.octopus.yml`); it
has **no** workspace config layer — `workspace:` currently feeds *rules* only
(RM-069). To honor all three layers, `qm_field` must read a third file,
`$OCTOPUS_WORKSPACE_PATH/.octopus.yml`, resolved from the project manifest's
`workspace:` key. Cheap and consistent with RM-069, but not free from cloning
`kr_field`.

## Testing Decisions

- **metrics-engine — unit.** The highest logic-risk module: dual-delta
  arithmetic, the ratchet-vs-absolute threshold rule, and parsing of the
  orphan-ref records. Pure logic, fully unit-testable.
- **config resolver — unit.** `qm_field` precedence (`default < workspace <
  personal < project`, project last) resolved **per field** across the three
  layer files; absent field → ratchet default. Lock the project-wins order so a
  future refactor can't silently invert it back to `kr_field`'s user-wins order.
- **adapters — integration.** Each adapter runs the real tooling against a small
  C#/TS fixture repo and asserts the normalized output matches the contract
  shape.
- **writer Action — end-to-end.** A lock test in the style of the existing
  "lock the focused-stack guarantee" e2e: a merge → `push:main` updates the
  orphan ref **and never touches a protected ref**.
- **skill orchestration — smoke.** Verifies the cost contract: no-breach → no
  LLM call (zero tokens); breach → curation fires. This is the guard that keeps
  the "≈0 tokens in the common case" promise honest.

## Out of Scope

- **Mutation testing** — deferred to v2. It is CPU-expensive and only meaningful
  once coverage is already being watched (it measures test *quality* over the
  quantity coverage measures). Adding it to v1 is premature optimization; when it
  lands, it runs on a separate pulse (nightly / test-files-changed), not per-PR.
- **AI-vs-human and per-agent attribution** — dropped entirely; every PR is
  measured identically regardless of author.
- **Cross-repo Tech-Manager trend dashboard** — a later aggregator over the
  per-repo refs; v1 only guarantees the data shape enables it.
- **Architecture/layering judgment on the dependency graph** — v1 detects cycles
  and the graph only; no verdict on layering violations.
- **A blocking CI gate** — the capability is advisory by design.
- **Adapters beyond C# and TypeScript** (e.g. Python) — later ports.

## Further Notes

Open questions the implementing agent should resolve before starting:

- **C# dependency tooling depth.** No free `madge` equivalent exists for C#; the
  v1 C# deps adapter will likely be thinner (assembly/project cycles via
  `dotnet list reference`) than the TS adapter (madge graph + cycles). Confirm
  the acceptable depth for the C# deps metric.
- **Concrete tool pinning per adapter** — e.g. `lizard` for cross-language
  complexity+size, `coverlet`→Cobertura and `vitest`→LCOV for coverage. Pin the
  exact tools and their output formats.
- **Orphan-ref ruleset exception.** Verify no catch-all (`**`) branch-protection
  rule or branch-creation restriction blocks the `octopus/*` ref prefix; if one
  exists, an exception must be opened before the writer can push.
- **Data shape on the ref** — a single overwritten `baseline.json` snapshot
  (tiny, fast fetch) versus an append-only `history.jsonl` (carries the trend
  directly). Decide which, and how the v2 mutation pulse will co-locate on the
  same ref.
- **Local `gh`/auth assumption** — the read path uses `git fetch`; confirm no
  additional auth surface is needed in the developer's local environment.
- **Low-cost model selection** — how the skill resolves "the harness's low-cost
  model" for the curation step across Codex / Claude Code / etc.
