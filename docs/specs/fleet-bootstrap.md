# Spec: fleet-bootstrap

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-30 |
| **Author** | Leonardo |
| **Status** | Approved (deep interview-refined 2026-05-30) |
| **RFC** | `docs/rfcs/2026-05-20-team-workspace-guardrails.md` (related — enforce-* origin) |
| **Roadmap** | RM-095 (Cluster 16) — pairs with RM-094 (`audit-fleet`), final home RM-096 (`tech-lead` bundle) |

## Problem Statement

Rolling a standard out to 6+ repos today means running `octopus setup` by hand in each, with no migration path for repos that already have a partial config. `audit-fleet` (RM-094) shows *where* the fleet drifts; this item *closes* the drift — bulk-applying a standard across many repos. Two realities of an actual fleet break the naïve "one canonical `.octopus.yml`" model and shape this spec:

- **Multi-stack.** The fleet spans stacks (.NET, Node, Python, frontend). There is no single standard manifest — a .NET repo needs the `dotnet`/`backend` bundle, a frontend repo needs `frontend`. The standard must be **layered**, not monolithic.
- **Legacy code.** Applying the full `guardrails` floor (block-no-verify, detect-secrets, typecheck, pre-commit, CI) to a legacy repo breaks commits immediately (typecheck fails, formatter rewrites huge diffs, detect-secrets flags existing test keys, CI goes red). Adoption must be **phased** (a ratchet), not a hard flip.

## Goals

- A capability `fleet-bootstrap` that converges a fleet onto a **layered standard** — a common baseline + per-stack profile + an adoption tier — running `octopus setup` in each repo.
- A **non-destructive migration path** for repos that already have an `.octopus.yml`: per-key diff, preview, merge on confirmation (never silent overwrite).
- **Phased adoption** for legacy via tiers (T0/T1/T2) anchored on the loop/git/CI enforcement layers.
- A single **source of truth** in the `workspace:` repo (a `fleet.yml`) the manager owns, alongside the shared rules and config templates.
- Safe by default: dry-run preview; per-repo confirmation; nothing destructive without a marker; never force-push.
- Pairs with `audit-fleet` (detect → remediate). Registered in the `tech-lead` bundle (RM-096).

## Non-Goals

- Not detection/reporting (that's `audit-fleet`).
- Not editing application code — only the Octopus config surface (`.octopus.yml` + what `octopus setup` materializes).
- Not a CI/CD pipeline — an operator-run bulk action.
- Not a force-push tool — operates on working trees/branches; commit+PR is the operator's (or a guarded `--pr`).
- Not a new seeding engine — it delegates the actual seeding of rules/hooks/agent-config to the existing `octopus setup`.

## Design

### Overview

`fleet-bootstrap` is a thin orchestrator. Per repo it: resolves the target (baseline + detected/declared stack profile + tier) from the `fleet.yml`, **composes** the repo's `.octopus.yml`, diffs it against what's there, previews, and on confirmation writes the manifest and runs `octopus setup`. **`octopus setup` does the actual seeding** — rules, hooks, agent config, `.editorconfig`, `.husky`/pre-commit — exactly as for a single repo. The bootstrap's only direct write is the `.octopus.yml`.

### D1 — The layered standard

The "standard" is composed, not a single file:

- **Baseline** (stack-agnostic, every repo): `agents`, `workflow`, the `workspace:` reference, baseline bundles (`quality`, `docs`, `tech-lead`), baseline roles (`architect`, `security`).
- **Stack profile** (per repo): adds the stack's bundles/skills. Selected by **auto-detection** (file signals) by default, **overridable** in the fleet list (legacy/monorepo/ambiguous stacks).
- **Adoption tier** (per repo, D2): which enforcement layers turn on.

Final per-repo manifest = **baseline ∪ profile(s) ∪ tier**, then merged with justified local keeps (D4).

Stack profiles (detection signals):

| Profile | Detect | Adds |
|---|---|---|
| `dotnet` | `*.sln`, `*.csproj` | bundle `backend`, skill `dotnet` |
| `node-backend` | `package.json` + (`express`/`fastify`/`nestjs`) | bundle `backend` |
| `frontend` | `package.json` + (`react`/`vue`/`next`), `src/pages/**` | bundle `frontend` |
| `python` | `pyproject.toml`, `requirements.txt` | bundle `backend` + `rules/python/*` |

### D2 — Adoption tiers (the legacy ratchet)

Octopus hooks are near-binary (no built-in "warn mode" for blockers), so tiers select **which enforcement layers turn on** rather than soften individual hooks. The key insight: **loop-level hooks only act on what the agent edits going forward — they do not retroactively fail legacy code**; the pre-commit (git) and CI layers are what break legacy.

| Tier | Turns on | Seeds | Effect on legacy |
|---|---|---|---|
| **T0 — Capabilities** | bundles/roles/rules/`workspace:`; `hooks: false` | agent config, rules (incl. workspace) | Zero enforcement. Personas + audits on-demand + rules as context. Safe on any legacy **immediately**. |
| **T1 — Loop-level** | `hooks: true` + `enforce-ide` | `.editorconfig` (per stack) | Catches new assistant drift; **does not** gate human commits or CI. `.editorconfig` is low-risk (affects new typing only). |
| **T2 — Full** | + `enforce-precommit` + `qualityWorkflow` | `.husky`/`.pre-commit-config.yaml` (per stack) + CI | The blocking floor on every commit/PR. Only when the repo is clean. |

A repo's tier lives in the fleet list; legacy starts at T0/T1, the manager ratchets up. **Tier de-escalation (e.g. T2→T0) is always flagged** (D4).

### D3 — Source of truth: `fleet.yml` in the `workspace:` repo

The `workspace:` repo already centralizes shared rules (symlinked into every repo). It is the natural home for one control file the manager owns — `fleet.yml` — carrying the baseline, the profiles, the tiers, and the repo map:

```yaml
# <workspace>/fleet.yml — the manager's single control file for the fleet.
baseline:
  agents: [claude, opencode]
  workflow: true
  workspace: git@github.com:acme/octopus-workspace.git
  bundles: [quality, docs, tech-lead]
  roles:   [architect, security]

profiles:
  dotnet:       { detect: ["*.sln", "*.csproj"],                 bundles: [backend], skills: [dotnet] }
  node-backend: { detect: ["package.json + (express|nestjs)"],   bundles: [backend] }
  frontend:     { detect: ["package.json + (react|next)"],       bundles: [frontend] }
  python:       { detect: ["pyproject.toml", "requirements.txt"], bundles: [backend] }

tiers:
  T0: { hooks: false, precommit: false, qualityWorkflow: false }
  T1: { hooks: true,  precommit: false, qualityWorkflow: false }   # + enforce-ide
  T2: { hooks: true,  precommit: true,  qualityWorkflow: true }    # + enforce-precommit + CI

repos:
  - { path: ../billing-api,   profile: dotnet,            tier: T0 }   # legacy .NET → inert
  - { path: ../checkout-web,                              tier: T1 }   # profile auto-detected (frontend)
  - { path: ../payments-svc,  profile: node-backend,      tier: T2 }
  - { path: ../data-pipeline, profile: python,            tier: T1 }
  - { path: ../legacy-erp,    profile: [dotnet, frontend], tier: T0 }  # mixed-stack monorepo
```

The repo's own `.octopus.yml` never contains `fleet`; it only receives the composed result. `audit-fleet` and `fleet-bootstrap` read the **same** `repos:` list.

**Composition example** — `payments-svc` (node-backend, T2) →

```yaml
agents: [claude, opencode]
workflow: true
workspace: git@github.com:acme/octopus-workspace.git
bundles: [quality, docs, tech-lead, backend]   # baseline ∪ profile
roles:   [architect, security]
hooks: true                                     # tier T2
qualityWorkflow: true                           # tier T2
```

`billing-api` (dotnet, T0) → same bundles/roles, but `hooks: false`, `qualityWorkflow: false`. The manager flips `tier: T0 → T1 → T2` in `fleet.yml` and re-runs — one file, one place.

### Seeding mechanics (delegated to `octopus setup`)

Per repo, `fleet-bootstrap`:

```
1. ensure the Octopus CLI is installed on the machine (prereq; not per-repo)
2. compose the .octopus.yml = baseline ∪ profile(s) ∪ tier        (from fleet.yml)
3. diff vs the repo's current .octopus.yml; preview (dry-run default)
4. on confirm, write the merged .octopus.yml and run `octopus setup`
   └─ setup seeds, per tier+stack:
        • agent config (.claude/, .opencode/, AGENTS.md + rules)
        • rules → .octopus/rules/ (workspace symlinked → fleet-wide updates propagate)
        • skills / roles / knowledge
        • T1+: enforce-ide  → .editorconfig (+ .vscode opt-in) per detected stack
        • T2+: enforce-precommit → .husky/.pre-commit-config.yaml per stack; qualityWorkflow CI
5. (optional --pr) open a branch + PR per repo; never push to main
```

The bootstrap writes only the `.octopus.yml`; `octopus setup` materializes everything else — identical to a single-repo install. Stack-specific `.editorconfig`/`.husky` are **generated by `enforce-ide`/`enforce-precommit` detecting each repo's stack** (a monorepo gets entries for each), idempotent and merge-respecting — not copied from fixed per-stack files.

### D4 — Merge policy (per-key; the migration path)

When a repo already has a divergent `.octopus.yml`, merge per key: **converge the baseline + tier, keep locals that match the profile, flag arbitrary divergence and any de-escalation — never remove silently.**

Worked example — `payments-svc` already had `bundles: [quality, backend, growth]`, `roles: [architect, backend-developer]`:

| Key | Local | Standard | Result |
|---|---|---|---|
| `bundles: quality, backend` | ✓ | ✓ | keep |
| `bundles: docs, tech-lead` | — | baseline | **converge** (add) |
| `bundles: growth` | ✓ | ✗ (neither baseline nor profile) | **⚠ conflict flagged** — keep or drop? |
| `roles: backend-developer` | ✓ | backend profile | **justified keep** (matches profile) |
| `roles: security` | — | baseline | converge (add) |
| `hooks: true` vs tier T0 | ✓ | T0 → false | **⚠ flagged** (de-escalation; never silent) |

`*.local.md` rule overrides survive automatically — the bootstrap only writes the manifest, and the rules layering already resolves `project > workspace > defaults`. The keep-vs-converge policy is the ADR (`fleet-merge-policy`).

### D5 — Workspace config-template layer (precedence)

Today `enforce-ide`/`enforce-precommit` *generate* `.editorconfig`/`.husky` from stack detection, with only **project-level** `*.local.md` overrides. This spec adds an optional **workspace template layer** so the manager curates the canonical editor/git standard once. Resolution per config file (highest wins):

1. **Project-local** — `enforce-ide.local.md` / `enforce-precommit.local.md`, or the repo's own committed file. Intentional repo choices, preserved/merged.
2. **Workspace template** — `<workspace>/templates/{ide,precommit,ci}/<stack>.*`. The fleet standard; **takes precedence over the Octopus generated default**.
3. **Octopus generated default** — today's stack-inferred generation; the fallback when the workspace provides nothing.

```
<workspace>/templates/
  ide/       dotnet.editorconfig   node.editorconfig   python.editorconfig
  precommit/ dotnet.pre-commit-config.yaml   node.husky/   ...
  ci/        quality.yml           # optional override of the Octopus CI template
```

The **profile (D1)** selects which stack template applies; the **merge policy (D4)** governs convergence (workspace template converges, project extras preserved, divergence flagged); the **tier (D2)** gates whether the git-level template is installed at all (T2). This is a small contract addition to `enforce-ide`/`enforce-precommit` — a "resolve workspace template before generating" step, mirroring how `deliver_rules` already pulls workspace rules.

### D6 — Relationship with `audit-fleet` + execution model (recommended)

- **Detect → remediate.** `fleet-bootstrap` shares the **repo-list resolver** with `audit-fleet`. It computes its own per-key manifest diff (it needs the precise diff to merge anyway), and optionally accepts `--from-audit <report>` to scope action to the repos `audit-fleet` flagged as drifted. Detect (RM-094) and remediate (RM-095) thus compose without one reimplementing the other.
- **Execution model (v1).** Operates on **local checkouts** (consistent with `audit-fleet` v1 — no remote/org infra). Dry-run is the default (preview, zero writes). `--apply` writes + runs setup. `--yes` skips per-repo confirmation for a trusted batch. `--pr` opens a guarded branch + PR per repo (never direct push to main, per project rules). An org-level GitHub Action variant is a heavier follow-up, flagged not built.

### Migration / Backward Compatibility

The migration path *is* the feature: existing `.octopus.yml`s are diffed and merged (D4), not clobbered. A repo with no config is a clean apply. Running with no flags previews only — zero risk to inspect. The workspace-template layer (D5) is additive: without workspace templates, generation behaves exactly as today.

## Implementation Plan

1. CLI surface `octopus fleet bootstrap` (and/or a skill `fleet-bootstrap/SKILL.md` that drives it) — dry-run default, `--apply`, `--yes`, `--pr`, `--from-audit`.
2. `fleet.yml` parser + the composer (`baseline ∪ profile(s) ∪ tier`), reusing the `audit-fleet` repo-list resolver and the `.octopus.yml` parser (`cli/lib/`); add a per-key `.octopus.yml` diff/merge helper (pure-bash) implementing D4.
3. Stack auto-detection (file signals per D1) with fleet-list override.
4. Tier → setup-flag mapping (`hooks`/`precommit`/`qualityWorkflow`) and the enforce-ide@T1 / enforce-precommit@T2 gating.
5. **D5** — extend `enforce-ide` + `enforce-precommit` with the workspace-template resolution step (project-local > workspace template > generated).
6. Register the skill in `bundles/tech-lead.yml` (RM-096); interim `bundles/quality.yml`.
7. `tests/test_fleet_bootstrap.sh` — grep/behavioral against a multi-repo, multi-stack fixture: dry-run writes nothing; composition layers correctly; T0 seeds no hooks; T2 seeds `.husky`; merge keeps profile-justified locals and flags arbitrary/de-escalation; workspace template beats generated default; never force-pushes.
8. **Documentation (required final deliverable — see below).**

### Documentation deliverable (explicit requirement)

The end-to-end **setup/seeding flow must be thoroughly documented on the GitHub Pages site, in every supported language (EN + pt-br), with flow diagrams and usage examples.** Concretely:

- `docs/site/skills/fleet-bootstrap.mdx` (+ pt-br pair with `source_hash`) and skills/commands index rows (EN + pt-br).
- A dedicated **"Fleet setup flow"** guide page (EN + pt-br) covering: the `workspace:` + `fleet.yml` model, the layered standard (baseline/profile/tier), the seeding chain (`fleet-bootstrap → octopus setup → enforce-*`), the config-template precedence (D5), and the merge policy (D4).
- **Mermaid flow diagrams** (rendered as inline SVG per the site convention): (a) the per-repo seeding sequence; (b) the tier ratchet T0→T1→T2 with what each layer turns on; (c) the config-resolution precedence (project-local > workspace template > generated).
- **Usage examples**: a first fleet bootstrap (dry-run → apply), promoting a legacy repo a tier, adding a new repo, the `--pr` guarded rollout, and `--from-audit` scoping.

## Context for Agents

**Knowledge modules**: [documentation]
**Implementing roles**: [backend-developer, tech-writer]
**Related ADRs**: [proposed: fleet-merge-policy; proposed: workspace-config-template-precedence]
**Skills needed**: [scaffold-skill, audit-fleet, enforce-ide, enforce-precommit]
**Bundle**: `quality (existing)` interim; `tech-lead (proposed, RM-096)` final
**Constraints**:
- Dry-run by default; never silent overwrite; tier de-escalation always flagged; never force-push.
- Only writes the `.octopus.yml`; delegates seeding to `octopus setup`.
- Layered standard (baseline + profile + tier); multi-stack and legacy are first-class.
- Reuse `audit-fleet` resolver + `.octopus.yml` parser; pure-bash; grep/behavioral test; pt-br site pair with source_hash.
- Documentation on GitHub Pages in all languages, with flow diagrams and usage examples, is a required deliverable.

## Testing Strategy

- Structural/behavioral test (above) against a multi-stack, multi-tier fixture (≥3 repos: a legacy .NET at T0, a clean Node at T2, a monorepo).
- Scenario checks: (1) dry-run on a drifted repo prints the per-key diff and writes nothing; (2) `--apply` composes baseline+profile+tier, runs setup, and a T0 repo gets no hooks while a T2 repo gets `.husky`; (3) a repo with a profile-justified local bundle keeps it; an arbitrary local bundle is flagged; (4) a tier de-escalation is flagged; (5) a workspace `.editorconfig` template overrides the generated default; (6) `--from-audit` scopes to flagged repos.

## Risks

- **Destructive convergence:** mitigated by the per-key merge (keep profile-justified locals), confirmation, a required marker for destructive removals, and flagging every de-escalation.
- **Merge-policy ambiguity (hard-converge vs preserve-local):** the real trade-off — recorded in the `fleet-merge-policy` ADR.
- **Mis-detection of stack on legacy/monorepo:** mitigated by the declarative profile override in the fleet list.
- **Over-eager enforcement on legacy:** mitigated by tiers — T0/T1 never touch the git/CI blocking layers.
- **Scale/auth across remotes:** v1 operates on local checkouts, consistent with `audit-fleet` v1; org-level variant flagged, not built.

## Changelog

- **2026-05-30** — Initial draft.
- **2026-05-30** — Deep interview refinement: layered standard (baseline + stack profile + adoption tier); T0/T1/T2 tiers anchored on loop/git/CI; `fleet.yml` in the `workspace:` repo as source of truth; per-key merge policy; workspace config-template precedence layer (D5) for `.editorconfig`/`.husky`; seeding delegated to `octopus setup`; `audit-fleet` detect→remediate contract + local-checkout execution; GitHub Pages documentation (all languages, flow diagrams, usage examples) made a required deliverable.
