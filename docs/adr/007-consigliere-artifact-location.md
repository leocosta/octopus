# ADR-007: consigliere artifacts ship generic in Octopus, data lives in the private workspace

## Status

Accepted — 2026-05-31

## Context

The `consigliere` initiative (Cluster 17) adds a role + skills (`digest-source`,
`context-status`, `playbook-review`) that digest a manager's diverse inputs into a
private `manager-workspace`. Two things could live in two different places: the
**code** of the artifacts (role + skills) and the **data** they produce (raw
sources, materialized state, journals, heuristics).

The data is non-negotiably private — meeting transcripts and political-risk notes
must never enter a team repo. The open question was only about the *code*: does the
role/skill code ship as part of Octopus (reusable, versioned), or does it live
inside the manager's own private repo (bespoke, self-contained)? Triggered by
`docs/research/2026-05-31-consigliere-workspace.md` (open question #2) and RM-099.

## Sources

- `docs/research/2026-05-31-consigliere-workspace.md` — open question #2.
- `docs/roadmap.md` — Cluster 17, RM-099 (scaffold + bundle).
- `docs/adr/005-workspace-config-template-precedence.md` — the "workspace owns the
  data, Octopus owns the generic engine" precedent this mirrors.

## Decision

**The `consigliere` role and skills ship generic in Octopus core.** They operate on
a `manager-workspace` whose location is supplied by configuration (a workspace
pointer), exactly as the fleet/workspace config layering already does. The
**data** — `sources/`, `contexts/`, `projects/`, `people/` — lives only in the
manager's private repo and is never part of Octopus.

Separation of concerns:

- **Octopus (versioned, public):** the role definition, the skill logic, the trio
  convention (`state/journal/playbook`), the `meta.yml` schema, the operating
  README template.
- **`manager-workspace` (private, per-user):** all digested content, materialized
  state, and seeded/captured heuristics.

## Alternatives Considered

### A — Generic in Octopus, data in the private workspace (chosen)

- **Pros:** reusable by any manager (the whole point of Octopus as a multiplier);
  versioned and improvable with releases; privacy preserved by keeping *data*, not
  *code*, in the private repo; mirrors ADR-005's proven "workspace owns the data"
  shape; skills get bug-fixes/upgrades centrally.
- **Cons:** the skills need a configurable workspace pointer instead of assuming a
  fixed path; one more config surface to document.

### B — Role + skills inside the private `manager-workspace`

- **Pros:** fully self-contained; nothing about the manager's setup leaks into a
  public repo.
- **Cons:** bespoke and non-reusable — every manager re-implements; no central
  upgrades; the *capability* (not just the data) becomes a one-off, defeating the
  manager-multiplier goal. Rejected.

### C — Hybrid (engine in Octopus, config/templates in the workspace)

- **Pros:** flexible per-workspace customization.
- **Cons:** premature — the only per-workspace thing identified so far is the
  playbook content, which is already *data*. No second config axis justifies the
  split yet (YAGNI). Can evolve into this later without re-deciding. Deferred.

## Consequences

### Positive

- The consigliere is a first-class, reusable Octopus capability, not a personal hack.
- Privacy holds: code is public, every byte of managerial content stays private.
- Consistent with the existing workspace-as-data-owner layering.

### Negative

- `digest-source` / `context-status` / `playbook-review` must resolve a workspace
  pointer (config) before reading/writing, rather than assuming `./`.

### Risks

- A misconfigured workspace pointer could write managerial data into the wrong
  (possibly team) repo — mitigated: the skills must validate the target is the
  configured private workspace and refuse to write elsewhere; grounding/preview
  step shows the absolute target path before any write.
