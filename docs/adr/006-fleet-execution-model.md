# ADR-006: fleet execution model — local checkouts (v1), org GitHub Action deferred

## Status

Accepted — 2026-05-30

## Context

The fleet skills — `audit-fleet` (RM-094, detect) and `fleet-bootstrap`
(RM-095, remediate) — both operate across many repos. *Where* they run is a
shared, hard-to-reverse choice: it shapes the auth model, the infra, and what a
manager has to set up. Recorded once for both. Triggered by
`docs/specs/audit-fleet.md` and `docs/specs/fleet-bootstrap.md`.

## Sources

- `docs/specs/audit-fleet.md`, `docs/specs/fleet-bootstrap.md` — both flag this.
- `cli/lib/audit-map.sh` / `audit-config` — the single-repo inspection reused.
- RM-094/095 interviews (2026-05-30).

## Decision

**v1 runs locally against checked-out repos.** Both skills resolve the fleet
list, then operate on local working trees (read-only for `audit-fleet`;
manifest write + `octopus setup` for `fleet-bootstrap`). An **org-level GitHub
Action** variant that scans/operates on remotes is explicitly **deferred**.

## Alternatives Considered

### A — Local checkouts (chosen for v1)

- **Pros:** zero infra; no org auth/secret handling; uses the existing
  single-repo logic directly; trivially testable with a local fixture; the
  manager already has the repos checked out.
- **Cons:** requires the repos to be present locally; not a hands-off org-wide
  scan.

### B — Org-level GitHub Action

- **Pros:** scales to the whole org without local checkouts; can run on a
  schedule.
- **Cons:** infra + auth/secrets across many remotes; clones or API access per
  repo; heavier to build and secure; harder to test. Real value, but a separate
  effort.

## Consequences

### Positive

- Both fleet skills ship without new infrastructure or org credentials.
- The same code path is exercised locally and in tests.

### Negative

- A manager must have (or check out) the repos locally to audit/bootstrap them.

### Risks

- Auth/secrets when scanning many remotes — **avoided in v1** by being local.
- A later Action variant must not fork the logic — it should call the same
  resolution + inspection + composition, only changing the execution surface.
