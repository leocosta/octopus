# Spec: tech-lead-bundle

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-30 |
| **Author** | Leonardo |
| **Status** | Draft |
| **RFC** | N/A |
| **Status** | Approved (interview-refined 2026-05-30) |
| **Roadmap** | RM-096 (Cluster 16) — ships last; all members now exist |

## Problem Statement

There is no bundle that composes the manager/tech-lead kit. A manager adopting Octopus has to hand-pick the right roles and skills. The other seven Cluster 16 items each ship a piece; this bundle is the **entry point** that packages them into one "I'm a tech manager, give me the kit" install. It ships **last**, after its members exist — shipping an empty bundle would violate the project's no-loose / no-empty convention.

## Goals

- A `tech-lead` bundle that composes the manager-multiplier capabilities into one install.
- Includes the Cluster 16 members plus the existing review roles a lead relies on (`architect`, `security`).
- Discoverable by the setup picker with a persona question ("are you leading a team / raising the bar across repos?").
- One `octopus setup` gives a lead the full apparatus; any other lead on the team inherits the same.

## Non-Goals

- No new capability of its own — it's a composition. (Every member is specced separately, RM-089…095.)
- Not a replacement for `quality`/`starter` — it *layers on top* (a lead still wants the baseline + audit gates).
- Not auto-enabled — opt-in via the persona question, like `quality`.

## Design

### Overview

A `bundles/tech-lead.yml` of `category: intent` with a persona question, listing the Cluster 16 skills + roles + the review roles. Bundle expansion (existing setup machinery) installs them together. No code beyond the bundle file and its doc — the members do the work.

**The manager's install, not a baseline bundle.** `tech-lead` is the kit a manager installs **on their control repo** — it carries the cross-repo *control-plane* tools (`audit-fleet`, `fleet-bootstrap`) that a leaf repo never needs. The **per-repo** leadership members (mentor, onboarding, DoD, standards, the `review-log-capture` hook) reach the fleet via the **baseline** (`docs` + `roles: [mentor, …]` + `hooks: true`), *not* via this bundle. So `tech-lead` is deliberately **excluded from the fleet baseline** (RM-095).

### Detailed Design

**Composition:**

```yaml
name: tech-lead
category: intent
persona_question: "Are you leading a team — raising the technical bar and autonomy across one or more repos?"
persona_default: false
skills:
  - standards                 # RM-092 — self-serve "what's our standard for X"
  - onboarding                # RM-090 — ramp a new engineer onto standards+code+flow
  - definition-of-done        # RM-091 — first-class team DoD + validation
  - continuous-learning       # RM-093 — team mode: recurring review feedback → rule candidates
  - audit-fleet               # RM-094 — cross-repo adoption + drift audit (control-plane)
  - fleet-bootstrap           # RM-095 — converge the fleet onto a layered standard (control-plane)
roles:
  - mentor                    # RM-089 — teaches the why
  - architect                 # existing — gates
  - security                  # existing — gates sensitive diffs
rules: []
mcp: []
hooks: null                   # composition bundle; capture hook reaches leaf repos via baseline hooks:true
```

Note `continuous-learning` (not a separate `team-continuous-learning`) — the team mode is part of the existing skill (RM-093). `fleet-bootstrap` ships as a skill (RM-095), so it is listed in `skills:`.

**List-in-both, not move.** Members stay registered in their interim bundles (`docs` for onboarding/DoD/standards/continuous-learning; `quality` for audit-fleet/fleet-bootstrap) **and** are listed here. The expander dedups. So a team that selects only `docs` still gets onboarding/standards/DoD; a manager selecting `tech-lead` gets the full kit — nothing is removed.

**Dependency ordering:** every listed member must exist before this bundle ships. Build order: RM-092 → 091 → 089 → 090 (pedagogy) → 094 → 095 (cross-repo) → 093 (team learning) → **096 (this) last**.

**Setup integration:** the existing bundle expander (`tests/test_bundles.sh` covers expansion) picks it up automatically once the file exists and members are registered; the persona question wires into the setup picker like the other intent bundles.

### Migration / Backward Compatibility

Additive. Opt-in. Existing bundles unchanged. Selecting `tech-lead` unions its members with whatever else is chosen (dedup by the expander), so `tech-lead` + `quality` + `starter` compose cleanly.

## Implementation Plan

1. `bundles/tech-lead.yml` — the composition above (all members now exist).
2. **List-in-both** — members stay in their interim bundles (`docs`/`quality`) and are also listed here; the expander dedups. Nothing is moved/removed.
3. **Fix the RM-095 baseline examples** — remove `tech-lead` from the `fleet.yml` baseline `bundles:` (it is the manager's install, not a baseline bundle); add `mentor` to the baseline roles. Affects the `fleet-bootstrap` spec + skill and the `fleet-setup-flow` site pages (EN + pt-br).
4. `tests/test_tech_lead_bundle.sh` — bundle exists, intent + persona, lists the members (which all exist — no-loose), and the fleet baseline does not list `tech-lead`.
5. Docs site: `docs/site/bundles/tech-lead.mdx` + pt-br pair; bundle index count bump eight → nine (EN + pt-br).

## Context for Agents

**Knowledge modules**: [documentation]
**Implementing roles**: [tech-writer]
**Related ADRs**: N/A
**Skills needed**: [scaffold-skill]
**Bundle**: this spec *defines* the bundle (`tech-lead (proposed)`)
**Constraints**:
- Ships only after all members exist (no empty/loose bundle).
- Composition only — no new capability logic here.
- pt-br site pair with source_hash; bundle index counts updated in both languages.

## Testing Strategy

- `tests/test_bundles.sh` expansion + dedup assertions for `tech-lead`.
- Scenario check: `bundles: [starter, quality, tech-lead]` expands to the expected union with no duplicates and includes `mentor` + `architect`.

## Risks

- **Shipping before members exist (empty bundle):** mitigated by the hard build-order dependency — this is the last item.
- **Overlap with `quality` (both list `architect`/`security`):** acceptable — the expander dedups; listing them documents that a lead relies on them even if `quality` isn't selected.

## Changelog

- **2026-05-30** — Initial draft.
- **2026-05-30** — Interview-refined: `tech-lead` is the manager's control-repo install, **excluded from the fleet baseline** (the per-repo leadership reaches leaf repos via `docs` + `mentor` role + `hooks: true`); members are **listed-in-both** (interim bundles + here, deduped), not moved; membership finalized (`continuous-learning` not `team-continuous-learning`; `fleet-bootstrap` as a skill); `hooks: null`; the RM-095 baseline examples corrected to drop `tech-lead`.
