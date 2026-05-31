# ADR-010: Knowledge-hygiene boundary with existing audit skills

## Status

Accepted — 2026-05-31

## Context

RM-107 introduces a generic `knowledge-hygiene` engine (staleness, orphans, broken links, archive, `--gaps`) over any registered knowledge root. Two existing skills overlap in spirit: `plan-backlog-hygiene` (orphan plans, broken internal links, stale plans, roadmap orphans in `docs/`) and `audit-config` (model drift, stale dates, phantom skills, deprecated paths across the Octopus config surface — rules/skills/hooks/commands/bundles). Cluster 19 exists specifically to kill the fragmentation of one-off hygiene skills, so the boundary with these two must be decided before RM-107 is written. See [spec](../specs/knowledge-root-registry.md) decision D1.

## Sources

- `docs/specs/knowledge-root-registry.md` — D1
- `docs/research/2026-05-31-knowledge-root-operations.md` — fragmentation argument
- `skills/plan-backlog-hygiene` — current scope
- `skills/audit-config` — current scope

## Decision

**Hybrid.** `plan-backlog-hygiene` is genuine markdown-tree hygiene over `docs/` and is folded into `knowledge-hygiene` as the `docs/` target view (the standalone skill becomes a thin alias / deprecation path, behavior preserved). `audit-config` is **not** folded: it audits the Octopus *configuration surface* (model drift, phantom skills, deprecated paths) — a different domain from knowledge-tree staleness — and stays a specialized, separate skill. The generic engine owns "is this markdown base decaying"; `audit-config` owns "is the Octopus config correct".

## Alternatives Considered

### Fold both into `knowledge-hygiene`

- **Pros:** maximal DRY; one hygiene entry point.
- **Cons:** `audit-config`'s checks (model-string drift, phantom skill references, deprecated cache paths) are not tree-staleness and do not fit a knowledge-root mould; forcing them in would bloat the engine's schema with config-specific concepts and couple two unrelated domains.

### Keep both specialized, engine covers only new roots

- **Pros:** zero regression risk to working skills.
- **Cons:** leaves `plan-backlog-hygiene` as a third hygiene silo — exactly the fragmentation Cluster 19 was created to remove; `docs/` would be audited by two different code paths.

## Consequences

### Positive

- One hygiene engine owns every markdown knowledge tree (`docs/`, memory, consigliere workspace) including `docs/plans`; no duplicate `docs/` hygiene path.
- `audit-config` keeps a sharp, single responsibility; the engine is not polluted with config-surface concepts.
- Clear rule for future skills: "markdown tree decaying" → knowledge-hygiene target; "Octopus config wrong" → audit-config.

### Negative

- `plan-backlog-hygiene` needs a migration: its `docs/`-specific checks (roadmap-entry-without-plan) become a `docs/`-target capability of the engine, and the old skill is aliased/deprecated — real work, not free.
- Until the fold lands, `docs/` plans hygiene must not regress; the engine's `docs/` target has to reach parity before the alias flips.

### Risks

- **Parity gap.** Folding before the engine reaches `plan-backlog-hygiene` parity would regress a working skill. Mitigation: RM-107 keeps `plan-backlog-hygiene` live until the `docs/` target passes its existing test cases, then aliases.
- **Boundary drift.** Future contributors may add config-ish checks to the engine or tree checks to `audit-config`. Mitigation: the decision rule above is recorded and referenced from both skills' docs.
