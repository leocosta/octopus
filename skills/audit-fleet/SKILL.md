---
name: audit-fleet
model: haiku
description: >
  Cross-repo adoption + drift audit. Given a fleet (from the workspace
  fleet.yml), reports each repo's Octopus surface against its declared target
  — baseline + stack profile + adoption tier — plus version and CONTEXT.md/ADR
  adoption. Signal-only: per-repo table + drift-hotspots rollup, feeds fleet-
  bootstrap --from-audit. Quality/tech-lead bundle.
triggers:
  keywords: ["fleet audit", "audit the fleet", "drift across repos", "across repos", "which repos", "fleet adoption", "fleet drift"]
---

# Fleet Audit

## Overview

`octopus setup` is per-repo, and `workspace:` shares rules — but a manager
over 6+ repos has no way to *see* which repos lag the standard. `audit-fleet`
gives that view: it resolves the fleet and reports, per repo, how its actual
Octopus config compares to the **target the team declared** in `fleet.yml`
(baseline + stack profile + adoption tier), plus Octopus version and
`CONTEXT.md`/ADR adoption.

It is the cross-repo analog of `audit-config`, and the **detect** half of the
fleet pair: `audit-fleet` finds the drift, [`fleet-bootstrap`](/octopus/skills/)
closes it. The report is built to feed `fleet-bootstrap --from-audit`.

The audit is **signal-only and read-only** — it never mutates a repo (that is
`fleet-bootstrap`'s job).

## When to Engage

Engage when the manager asks which repos are behind, how adopted the standard
is, or where the fleet drifts. Manual, operator-run.

## Fleet resolution

Resolve the repo list, in precedence (the **same** list `fleet-bootstrap`
uses):

1. **`fleet.yml`** in the `workspace:` repo — the source of truth. Its
   `baseline` / `profiles` / `tiers` let the audit compute each repo's
   **target**; its `repos:` is the list. Primary.
2. An explicit `fleet:` list in the orchestrator repo's `.octopus.yml` — when
   there is no `fleet.yml`.
3. A passed argument (local paths), or local discovery of sibling directories
   containing `.octopus.yml`.

Without a `fleet.yml`, the audit degrades to generic baseline checks
(version / bundles / hooks / `CONTEXT.md`) with no target-tier comparison.

## Per-repo inspection — actual vs target (read-only)

For each repo, compute the **target** (`baseline ∪ profile(s) ∪ tier`, the
same composition `fleet-bootstrap` would apply) and compare:

- **Adoption tier** — the repo's effective tier (from `hooks` / `precommit` /
  `qualityWorkflow`) vs its declared `tier`. Below target = drift; above
  target is flagged too.
- **Stack profile** — bundles present vs the profile's expected bundles, and
  whether the detected stack matches the declared profile.
- **Bundles** — enabled vs the composed target (missing baseline/profile
  bundles).
- **Octopus version** — installed CLI/cache version vs latest (behind = drift).
- **Rules drift** — `rules/*.local.md` + workspace-pulled rules vs the
  baseline (hash/diff).
- **Encode adoption** — `CONTEXT.md` present? ADR count? (the layer
  `audit-grounding` depends on).

Reuse the single-repo logic from `audit-config` / `cli/lib/audit-map.sh`
rather than reimplementing config inspection.

## Report shape (signal-only)

- **Per-repo table:** repo · version · target tier → actual tier · profile
  match? · missing bundles · `CONTEXT.md`? · ADRs · drift flags.
- **Drift-hotspots rollup:** the gaps with the widest spread first — e.g. "5/7
  repos behind the Octopus version", "3/7 below their target tier", "6/7 have
  no `CONTEXT.md`" — so the manager sees the biggest standardization gaps
  first.
- **Suggested action:** points at `fleet-bootstrap` to remediate; note the
  report can be fed via `fleet-bootstrap --from-audit <report>`.

```
Fleet Audit — 4 repos
=====================
repo           version   tier (target→actual)   profile   missing bundles   CONTEXT.md   ADRs   drift
billing-api    1.62 ⚠    T0 → T0  ✓              dotnet ✓  —                 ✗ ⚠         0      version, no-context
payments-svc   1.69 ✓    T2 → T1  ⚠              node ✓    —                 ✓           3      below-tier
checkout-web   1.69 ✓    T1 → T1  ✓              frontend✓ —                 ✗ ⚠         1      no-context
legacy-erp     1.55 ⚠    T0 → T0  ✓              dotnet+fe —                 ✗ ⚠         0      version, no-context

Hotspots: 2/4 behind version · 3/4 no CONTEXT.md · 1/4 below target tier
→ remediate with `fleet-bootstrap --apply` (or `--from-audit` this report)
```

## Execution model

v1 runs **locally against checked-out repos** (simplest, no infra) — consistent
with `fleet-bootstrap` v1. An org-level GitHub Action scanning remotes is a
heavier follow-up (auth/secrets); flagged, not built.

## Anti-Patterns

- **Mutating a repo** — `audit-fleet` only reports; remediation is
  `fleet-bootstrap`.
- **Reimplementing `audit-config`** — reuse its single-repo checks.
- **A flat list with no target** — when `fleet.yml` exists, measure against the
  declared target (tier + profile), not a vague baseline.
- **Burying the signal** — lead with the hotspots rollup; the per-repo table is
  the detail.

## Integration with Other Skills

- **`fleet-bootstrap`** — the remediation half; shares the fleet list;
  consumes this report via `--from-audit`.
- **`audit-config`** — the single-repo checks this audit reuses across the fleet.
- **`audit-grounding`** — depends on the `CONTEXT.md`/ADR adoption this audit
  surfaces.
- **`tech-lead` bundle** — the final home; interim `quality`.
## Model tier

This audit is mechanical — it pattern-matches a diff against a fixed
checklist, not deep reasoning. Run it on the **cheapest model tier**
(`--model haiku` / each assistant's cheapest). Reserve frontier models
for the `architect`/`dba`/`security` roles that adjudicate the findings
(RM-130).
