# ADR-005: workspace config-template precedence for .editorconfig / pre-commit

## Status

Accepted — 2026-05-30

## Context

`enforce-ide` and `enforce-precommit` **generate** `.editorconfig` and the
pre-commit / `.husky` config by detecting a repo's stack, with only
**project-level** `*.local.md` overrides. For a fleet (RM-095) the manager wants
to curate **one** canonical editor/git standard and have it distributed to every
repo — taking precedence over Octopus's generic generated defaults. Adding a
workspace layer here is a contract change to two existing skills, so it is
recorded. Triggered by `docs/specs/fleet-bootstrap.md` (D5).

## Sources

- `docs/specs/fleet-bootstrap.md` — D5.
- `skills/enforce-ide/SKILL.md`, `skills/enforce-precommit/SKILL.md` — the skills
  being extended.
- `setup.sh` `deliver_rules` — the existing `project > workspace > defaults` rules
  layering this mirrors.
- `docs/rfcs/2026-05-20-team-workspace-guardrails.md` — the enforce-* origin.

## Decision

Add a **workspace config-template layer** to `enforce-ide` and
`enforce-precommit`. Resolve each config file with this precedence (highest wins):

1. **Project-local** — the repo's own committed config / `*.local.md` directives.
2. **Workspace template** — `<workspace>/templates/{ide,precommit,ci}/<stack>.*`,
   used as the canonical base, **overriding the generated default**.
3. **Generated default** — today's stack-inferred generation; the fallback.

The stack profile (RM-095 D1) selects which template; the merge policy
(ADR-004) governs convergence; the adoption tier (RM-095 D2) gates whether the
git-level template is installed at all (T2).

## Alternatives Considered

### A — Workspace template layer with the three-level precedence (chosen)

- **Pros:** the manager curates the standard once; mirrors the proven rules
  layering; backward-compatible (no templates → today's behavior); falls back to
  generation per-stack where the workspace is silent.
- **Cons:** a contract addition to two skills; a new `<workspace>/templates/` shape
  to document.

### B — Keep generation-only, project-level overrides only (status quo)

- **Pros:** no change.
- **Cons:** no fleet-wide editor/git standard; every repo re-derives generically;
  the manager can't centralize. Rejected for the fleet use case.

### C — Ship fixed per-stack template files inside Octopus

- **Pros:** consistent defaults.
- **Cons:** not the *team's* standard; couples the standard to Octopus releases;
  no per-fleet customization. Rejected — the workspace is the right owner.

## Consequences

### Positive

- One curated editor/git standard distributes across the fleet with precedence.
- Generation remains the graceful fallback; nothing breaks without templates.
- Consistent with how rules already layer from the workspace.

### Negative

- `enforce-ide` / `enforce-precommit` gain a resolution step before generating.

### Risks

- A workspace template that diverges from a repo's intentional local choice —
  mitigated: project-local wins (level 1), and the merge stays conservative.
