---
name: fleet-bootstrap
description: >
  Converge a fleet of repos onto a layered Octopus standard (baseline + per-
  stack profile + adoption tier) by composing each repo's .octopus.yml from
  one fleet.yml and running octopus setup in each. Multi-stack and legacy
  first-class; tiers T0/T1/T2 phase adoption. Dry-run by default, non-
  destructive per-key merge, never force-pushes. Pairs with audit-fleet.
  Manual; quality/tech-lead bundle.
triggers:
  keywords: ["fleet bootstrap", "bootstrap the fleet", "roll out octopus", "standardize repos", "bulk octopus setup", "converge the fleet"]
---

# Fleet Bootstrap

## Overview

Standardizing 6+ repos by hand — `octopus setup` in each terminal — does
not scale, and a fleet is **multi-stack** (a .NET repo needs different
bundles than a frontend repo) and carries **legacy code** (a hard
`guardrails` flip breaks legacy commits instantly). `fleet-bootstrap`
closes the drift `audit-fleet` detects: it composes each repo's
`.octopus.yml` from one control file and runs setup, with a layered
standard and a phased (ratchet) adoption.

It is a **thin orchestrator**: the only thing it writes directly is the
`.octopus.yml`. The actual seeding — rules, hooks, agent config,
`.editorconfig`, `.husky` — is delegated to **`octopus setup`**, exactly as
for a single repo.

## When to Engage

Manual, operator-run. Engage when the manager wants to roll a standard
across the fleet, onboard a new repo to the standard, or ratchet a legacy
repo up a tier. Not auto-invoked.

## The source of truth — `fleet.yml`

One file in the **`workspace:` repo** (alongside the shared rules) carries
everything; the target repos never contain `fleet`, they only receive the
composed result.

```yaml
# <workspace>/fleet.yml
baseline:                       # every repo, any stack, any tier
  agents: [claude, opencode]
  workflow: true
  workspace: git@github.com:acme/octopus-workspace.git
  bundles: [quality, docs]      # per-repo leadership via docs + mentor + hooks
  roles:   [mentor, architect, security]
  # NOTE: the `tech-lead` bundle is the manager's control-repo install,
  # NOT a baseline bundle — it carries the cross-repo control tools (audit-fleet,
  # fleet-bootstrap) that leaf repos don't need.

profiles:                       # what each stack adds; selected by detection or pinned
  dotnet:       { detect: ["*.sln", "*.csproj"],                 bundles: [backend], skills: [dotnet] }
  node-backend: { detect: ["package.json + (express|nestjs)"],   bundles: [backend] }
  frontend:     { detect: ["package.json + (react|next)"],       bundles: [frontend] }
  python:       { detect: ["pyproject.toml", "requirements.txt"], bundles: [backend] }

tiers:                          # which enforcement layers turn on (D2)
  T0: { hooks: false, precommit: false, qualityWorkflow: false }
  T1: { hooks: true,  precommit: false, qualityWorkflow: false }   # + enforce-ide
  T2: { hooks: true,  precommit: true,  qualityWorkflow: true }    # + enforce-precommit + CI

repos:                          # the map: each repo's profile (optional) + tier
  - { path: ../billing-api,   profile: dotnet,            tier: T0 }
  - { path: ../checkout-web,                              tier: T1 }   # profile auto-detected
  - { path: ../payments-svc,  profile: node-backend,      tier: T2 }
  - { path: ../legacy-erp,    profile: [dotnet, frontend], tier: T0 }  # monorepo
```

`audit-fleet` and `fleet-bootstrap` resolve the **same** `repos:` list.

## The layered standard

The composed manifest is **baseline ∪ profile(s) ∪ tier**:

- **Baseline** — stack-agnostic, every repo (agents, workflow, `workspace:`,
  baseline bundles, baseline roles).
- **Stack profile** — selected by **auto-detection** (the `detect` signals:
  `*.csproj` → dotnet, `package.json`+framework → node/frontend,
  `pyproject.toml` → python) by default, **overridable** by pinning
  `profile:` in the fleet list (legacy / monorepo / ambiguous stack).
- **Adoption tier** — see below.

## Adoption tiers — the legacy ratchet

Octopus hooks have no built-in warn mode, so tiers select *which
enforcement layers turn on*. Loop-level hooks only act on what the agent
edits going forward — they do **not** retroactively fail legacy code; the
pre-commit (git) and CI layers are what break legacy.

| Tier | Turns on | Seeds (via setup) | Legacy effect |
|---|---|---|---|
| **T0** | bundles/roles/rules; `hooks: false` | agent config, rules | zero enforcement — safe on any legacy now |
| **T1** | `hooks: true` + `enforce-ide` | `.editorconfig` per stack | catches new assistant drift; no commit/CI gate |
| **T2** | + `enforce-precommit` + `qualityWorkflow` | `.husky`/pre-commit per stack + CI | full blocking floor — only when clean |

Legacy repos start at T0/T1; the manager bumps `tier:` in `fleet.yml` and
re-runs. The tier flips the `hooks` / `precommit` / `qualityWorkflow`
manifest values that `octopus setup` reads.

## Per-repo flow

```
1. ensure the Octopus CLI is installed on the machine (prereq, not per-repo)
2. resolve the repo's profile (detected or pinned) + tier from fleet.yml
3. compose .octopus.yml = baseline ∪ profile(s) ∪ tier
4. diff vs the repo's current .octopus.yml; PREVIEW (dry-run is the default)
5. on confirm (--apply), write the merged manifest and run `octopus setup`
   └─ setup seeds rules/hooks/agent-config/.editorconfig/.husky per tier+stack
6. (optional --pr) open a branch + PR per repo — never push to main
```

The skill writes **only the `.octopus.yml`**; everything else is `octopus
setup`'s job. Stack-specific `.editorconfig`/`.husky` are generated by
`enforce-ide`/`enforce-precommit` detecting each repo's stack (a monorepo
gets both), idempotent and merge-respecting.

## Merge policy — the migration path

When a repo already has a divergent `.octopus.yml`, merge **per key**:

- **Converge** the baseline + tier values (add what's missing; set the
  tier's `hooks`/`precommit`/`qualityWorkflow`).
- **Keep** local additions that **match the repo's profile** (e.g. a
  `backend-developer` role in a backend repo) — a justified keep.
- **Flag** (never silently remove) local additions that match neither
  baseline nor profile (e.g. an arbitrary `growth` bundle) — a conflict the
  operator resolves.
- **Flag every tier de-escalation** (e.g. the standard's T0 would turn off
  `hooks` a repo currently has on) — ratcheting up is normal; reducing
  enforcement is always surfaced.
- **`*.local.md` rule overrides survive automatically** — the skill only
  writes the manifest, and the rules layering already resolves
  `project > workspace > defaults`.

A destructive removal requires an explicit marker; nothing is clobbered.

## Modes & safety

- **Dry-run is the default** — preview the per-repo diff, write nothing.
- **`--apply`** — write the merged manifest and run `octopus setup`.
- **`--yes`** — skip per-repo confirmation for a trusted batch.
- **`--pr`** — open a guarded branch + PR per repo. **Never pushes to
  main** (per project rules); leaves merge to the operator.
- **`--from-audit <report>`** — scope action to the repos `audit-fleet`
  flagged as drifted (shares the repo-list resolver with `audit-fleet`).
- **v1 operates on local checkouts** (consistent with `audit-fleet` v1); an
  org-level GitHub Action variant is a later, heavier follow-up.

## Anti-Patterns

- **Seeding rules/hooks directly** — always delegate to `octopus setup`;
  the skill owns only the `.octopus.yml`.
- **A monolithic standard** — the standard is layered; never apply one
  manifest uniformly across stacks.
- **Hard-flipping guardrails on legacy** — use tiers; T0/T1 never touch the
  git/CI blocking layers.
- **Silent overwrite or force-push** — every divergence is previewed;
  de-escalations and arbitrary keeps are flagged; commits/PRs are the
  operator's.

## Integration with Other Skills

- **`audit-fleet`** — detect → remediate: shares the repo-list
  resolver; `--from-audit` scopes remediation to flagged repos.
- **`octopus setup`** — does the actual seeding the skill orchestrates.
- **`enforce-ide` / `enforce-precommit`** — the T1/T2 layers, including the
  workspace config-template precedence.
- **`tech-lead` bundle** — the final home; interim `quality`.
