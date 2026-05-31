# ADR-008: consigliere ships as a separate bundle, not merged into tech-lead

## Status

Accepted — 2026-05-31

## Context

Cluster 16 shipped the `tech-lead` bundle (RM-096) — the manager-as-team-multiplier
kit (mentor, onboarding, definition-of-done, standards, audit-fleet, etc.).
Cluster 17 adds the `consigliere` role + skills — the manager-as-self-multiplier
kit (digest-source, context-status, playbook-review). Every new Octopus skill must
map to a bundle, so the question is whether `consigliere` is a new bundle or folds
into `tech-lead`. Triggered by `docs/research/2026-05-31-consigliere-workspace.md`
(open question #4) and RM-099.

## Sources

- `docs/research/2026-05-31-consigliere-workspace.md` — open question #4.
- `docs/roadmap.md` — Cluster 16 (RM-096 `tech-lead` bundle) and Cluster 17.
- Bundle convention: every skill maps to an existing bundle or proposes a new one;
  nothing ships loose.

## Decision

**Ship `consigliere` as a new, separate bundle.** It is not merged into `tech-lead`.

The two bundles differ on every axis that justifies a bundle boundary:

| Axis | `tech-lead` | `consigliere` |
|------|-------------|---------------|
| Audience | the manager acting **on the team** | the manager managing **themselves** |
| Data | team repos, PRs, shared standards | a **private** single-user workspace |
| Activation context | code review, onboarding, fleet ops | digesting meetings/docs, status recall |
| Privacy posture | public / shared | strictly private |

## Alternatives Considered

### A — Separate `consigliere` bundle (chosen)

- **Pros:** clean activation boundary — consigliere skills never load in a
  code-review/fleet context and vice versa; the privacy posture is bundle-level, not
  per-skill; each bundle evolves independently; honest mapping of audience→bundle.
- **Cons:** two manager-oriented bundles to discover instead of one umbrella.

### B — Merge into `tech-lead`

- **Pros:** a single "manager kit" to install; one discovery surface.
- **Cons:** mixes team-facing code tooling with private managerial knowledge;
  loads consigliere skills in code-review contexts (noise, and a privacy smell);
  couples two release cadences and audiences. Rejected — the boundary is real.

## Consequences

### Positive

- Activation stays scoped: digesting inputs doesn't pull in PR/fleet skills.
- Privacy is expressed at the bundle level, reinforcing ADR-007's data/code split.
- `tech-lead` and `consigliere` can be installed, versioned, and reasoned about
  independently.

### Negative

- A manager wanting "everything" installs two bundles rather than one.

### Risks

- Future skills that genuinely serve both (e.g. a skill that turns a private
  consigliere insight into a team standard) would straddle the boundary — mitigated:
  place such a skill in whichever bundle owns its *primary* activation context, and
  cross-reference; do not merge the bundles to accommodate an edge case.
