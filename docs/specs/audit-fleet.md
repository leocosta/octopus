# Spec: audit-fleet

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-30 |
| **Author** | Leonardo |
| **Status** | Approved (aligned to the RM-095 fleet model 2026-05-30) |
| **RFC** | N/A |
| **Roadmap** | RM-094 (Cluster 16) — the *detect* half of detect → remediate; pairs with RM-095 (`fleet-bootstrap`) |

## Problem Statement

Octopus setup is per-repo. `workspace:` shares *rules*, but a manager over 6+ repos has **no way to see which repos lag the standard** — old Octopus version, missing bundles, the wrong adoption tier, rules drifting from the workspace baseline, hooks disabled, no `CONTEXT.md`. The manager is blind to fleet adoption and drift, which forces opening each repo by hand. This is the cross-repo payoff item.

## Goals

- A skill `audit-fleet` that, given the fleet, **reports adoption and drift** of each repo **against its declared target** in `fleet.yml` (the RM-095 source of truth) — baseline + stack profile + adoption tier — plus Octopus version, `CONTEXT.md`/ADR presence.
- **Signal-only** — a report, never a mutation (mirrors `audit-config`/`audit-grounding`).
- A consolidated table the manager can scan: per-repo target vs actual + drift flags, plus a **drift-hotspots** rollup (what's most inconsistent across the fleet).
- The report **feeds `fleet-bootstrap --from-audit`** — detect here, remediate there.
- Registered in the `tech-lead` bundle (RM-096); interim `quality`.

## Non-Goals

- Not the fixer — bulk remediation is RM-095. This only *detects and reports*.
- Not management metrics (velocity, people) — strictly Octopus-config adoption/drift.
- Not a live dashboard/telemetry service — an on-demand audit producing a report artifact.
- Not single-repo config freshness (that's `audit-config`); this is the *cross-repo* view.

## Design

### Overview

An orchestration skill that resolves the fleet from `fleet.yml`, computes each repo's **target** (baseline ∪ profile ∪ tier — the same composition `fleet-bootstrap` would apply), inspects the repo's actual Octopus surface (reusing `audit-config`'s single-repo checks where possible), and synthesizes a fleet report: a per-repo row (target vs actual) plus a drift-hotspots rollup. The cross-repo analog of `audit-config`, measured against the declared standard.

### Detailed Design

**Fleet resolution (in precedence):**
1. **`fleet.yml`** in the `workspace:` repo (the RM-095 source of truth — `repos:` + `baseline`/`profiles`/`tiers` to compute each repo's target). Primary.
2. An explicit `fleet:` list in the orchestrator repo's `.octopus.yml` (paths/URLs) — when there is no `fleet.yml`.
3. A passed argument (list of local paths), or local discovery of sibling dirs containing `.octopus.yml`.

`audit-fleet` and `fleet-bootstrap` resolve the **same** `repos:` list.

**Per-repo inspection (read-only) — actual vs target:**
- **Adoption tier** — the repo's effective tier (from `hooks`/`precommit`/`qualityWorkflow`) vs its declared `tier` in `fleet.yml`. Below target = drift; above = flagged too.
- **Stack profile** — bundles present vs the profile's expected bundles (and whether the detected stack matches the declared profile).
- **Bundles** — enabled vs the composed target (missing baseline/profile bundles).
- **Octopus version** — installed CLI/cache version vs latest (drift if behind).
- **Rules drift** — `rules/*.local.md` and workspace-pulled rules vs the baseline (hash/diff).
- **Encode adoption** — `CONTEXT.md` present? ADR count? (the layer `audit-grounding` depends on.)

**Report shape (signal-only):**
- **Per-repo table:** repo · version · target tier → actual tier · profile match? · missing bundles · CONTEXT.md? · ADRs · drift flags.
- **Drift-hotspots rollup:** "5/7 repos behind the Octopus version", "3/7 below their target tier", "6/7 have no `CONTEXT.md`" — sorted by spread, so the manager sees the biggest gaps first.
- **Suggested action:** points at `fleet-bootstrap` to remediate, and notes the report can be fed via `--from-audit`.

**Execution model:** v1 runs locally against checked-out repos (simplest, no infra) — consistent with `fleet-bootstrap` v1. An org-level GitHub Action variant scanning remotes is a heavier follow-up; flagged, not built (ADR-006).

**Reuse:** the per-repo checks call the existing `audit-config` logic / `cli/lib/audit-map.sh` patterns rather than reimplement config inspection; the fleet/target resolution is shared conceptually with `fleet-bootstrap`.

### Migration / Backward Compatibility

Additive, read-only — no effect on any repo. Works with a 1-repo "fleet" (degenerate case), so it's testable without a real fleet. Without a `fleet.yml`, it degrades to the generic baseline checks (version/bundles/hooks/CONTEXT.md) with no target-tier comparison.

## Implementation Plan

1. `skills/audit-fleet/SKILL.md` — frontmatter (cues; `triggers.keywords`: "fleet audit", "across repos", "which repos", "adoption", "drift across"); fleet resolution from `fleet.yml`; target composition (baseline ∪ profile ∪ tier); per-repo actual-vs-target inspection; report shape; explicit signal-only + points-to-`fleet-bootstrap` (`--from-audit`).
2. `cli/lib/` helper (optional) — a `fleet_resolve` + per-repo inspect function reusing `audit-config`/`audit-map` logic, pure-bash.
3. Register in `bundles/quality.yml` (interim, sibling of `audit-config` + `fleet-bootstrap`); `bundles/tech-lead.yml` (RM-096) final.
4. `tests/test_audit_fleet.sh` — grep-structural: skill exists; resolves the fleet from `fleet.yml`; computes target = baseline+profile+tier; per-repo actual-vs-target checks (tier, profile, bundles, version, CONTEXT.md); drift-hotspots rollup; signal-only; references `fleet-bootstrap`/`--from-audit`.
5. **ADR-006** — fleet execution model (local checkouts v1 vs org GitHub Action) — shared by RM-094/095.
6. Docs site: `docs/site/skills/audit-fleet.mdx` + pt-br pair; skills index rows (EN + pt-br).

## Context for Agents

**Knowledge modules**: [documentation]
**Implementing roles**: [backend-developer]
**Related ADRs**: [proposed: ADR-006 fleet-execution-model-local-vs-action]
**Skills needed**: [scaffold-skill, audit-config, fleet-bootstrap]
**Bundle**: `quality (existing)` interim; `tech-lead (proposed, RM-096)` final
**Constraints**:
- Read-only across the fleet; never mutates a repo (that's RM-095).
- Measures drift against the declared target (baseline+profile+tier) from `fleet.yml`.
- Reuse `audit-config` / `cli/lib/audit-map.sh` rather than reimplement.
- Pure-bash helpers; markdown skill; grep-based test; pt-br site pair with source_hash.

## Testing Strategy

- Structural grep test (above).
- Scenario check: a two-repo fixture (one at its target tier, one drifted — below target tier, missing a profile bundle, no `CONTEXT.md`) yields a table marking the drift and a hotspots rollup, and points at `fleet-bootstrap`.

## Risks

- **Execution model (local vs org Action):** the real trade-off — local is simple but needs checkouts; an Action scales to the org but adds infra/auth. ADR-006; v1 = local, Action deferred.
- **Auth/secrets when scanning many remotes:** avoided in v1 (local only).
- **Reimplementing `audit-config`:** mitigated by mandated reuse.
- **Drift against a target that doesn't exist (no `fleet.yml`):** graceful degradation to generic baseline checks.

## Changelog

- **2026-05-30** — Initial draft.
- **2026-05-30** — Aligned to the RM-095 fleet model: resolves `fleet.yml`; measures each repo's drift against its declared target (baseline + stack profile + adoption tier); report feeds `fleet-bootstrap --from-audit`; execution-model decision moved to shared ADR-006.
