# ADR-002: mentor as a separate role vs. a teach-mode on architect

## Status

Accepted — 2026-05-30

## Context

The gate roles (`architect`, `dba`, `security`) judge a diff and emit
`BLOCKING/ADVISORY/QUESTION` verdicts, but they do not teach the reasoning behind
each finding. RM-089 adds a pedagogy capability to raise team autonomy (the
manager's nº1 goal). The implementation choice is interface-shaping and hard to
reverse once dispatch aliases and the `tech-lead` bundle depend on it, so it is
recorded here. Triggered by `docs/specs/mentor-role.md`.

## Sources

- `docs/specs/mentor-role.md` — the spec and its Risks section.
- `roles/architect.md` — the gate role's output contract (severity classification).
- `docs/research/2026-05-30-manager-multiplier.md` §7 — open question on this split.
- `skills/delegate/SKILL.md` — the dispatch/alias surface that would depend on it.

## Decision

Ship pedagogy as a **separate `mentor` role** that consumes the gate roles'
already-produced findings and emits teaching units — **not** as a "teach mode"
flag on `architect`.

## Alternatives Considered

### A — Separate `mentor` role (chosen)

- **Pros:** gating and teaching stay separate concerns with separate output
  shapes; a PR can be gated by `architect` **and** taught by `mentor` without
  either diluting the other; mentor can teach across all gate roles
  (architect/dba/security), not just one; clean on-demand invocation via
  `delegate`.
- **Cons:** a new role to install and maintain; the mentor must parse another
  role's findings format.

### B — `--teach` mode on `architect`

- **Pros:** no new role; reuses architect's analysis in one pass.
- **Cons:** conflates two jobs with opposite failure modes (a gate that hedges to
  teach is a worse gate; a verdict that only says "blocked" teaches nothing);
  couples teaching to architect alone, leaving dba/security findings untaught;
  bloats one persona with two output contracts.

## Consequences

### Positive

- The gate stays sharp; the lesson stays grounded. Each can evolve independently.
- Mentor teaches the why behind DB and security gates too, not only architecture.
- Read-only-by-default mentor adds zero artifacts unless `--save`/`--pr` are used.

### Negative

- Two roles can both comment on one change — the user must invoke mentor
  explicitly (mitigated: on-demand only, no automatic dispatch).

### Risks

- Overlap/confusion with the gate roles — mitigated by the explicit non-gate
  boundary in `roles/mentor.md` and by this ADR.
- Findings-format drift: if a gate role changes its output shape, mentor's parser
  must follow — mitigated by mentor consuming the human-readable report, not a
  brittle machine contract.
