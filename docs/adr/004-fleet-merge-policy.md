# ADR-004: fleet-bootstrap merge policy — per-key converge, preserve justified locals

## Status

Accepted — 2026-05-30

## Context

`fleet-bootstrap` (RM-095) converges a fleet of repos onto a standard. Many
repos already have an `.octopus.yml` — some adopted Octopus independently, with
local bundles, roles, or `hooks` settings. How the bootstrap reconciles the
standard with a repo's existing manifest is the central, hard-to-reverse choice:
once the fleet runs on it, the policy shapes what survives and what converges
across every repo. Triggered by `docs/specs/fleet-bootstrap.md`.

## Sources

- `docs/specs/fleet-bootstrap.md` — the spec (D4) and its Risks.
- `setup.sh` `deliver_rules` — the existing `project > workspace > defaults` rules
  layering this policy is consistent with.
- RM-095 interview (2026-05-30) — where the policy and examples were set.

## Decision

Merge **per key**, not whole-file:

- **Converge** the baseline + tier values (add missing baseline keys; set the
  tier's `hooks` / `precommit` / `qualityWorkflow`).
- **Keep** local additions that match the repo's resolved **stack profile** (a
  justified keep — e.g. `backend-developer` in a backend repo).
- **Flag, never silently remove**, local additions matching neither baseline nor
  profile.
- **Flag every tier de-escalation** (a standard that would reduce a repo's current
  enforcement) — ratcheting up is normal; reducing is always surfaced.
- `*.local.md` rule overrides survive automatically — the bootstrap writes only
  the manifest; the rules layering keeps `project` on top.

## Alternatives Considered

### A — Per-key converge, preserve justified locals (chosen)

- **Pros:** converges the essential standard while respecting intentional,
  stack-justified local choices; nothing is clobbered; surfaces real conflicts
  for a human. Matches the existing rules-layering philosophy.
- **Cons:** more logic than whole-file replace; "justified vs arbitrary" needs the
  profile to disambiguate.

### B — Hard converge (standard replaces the whole manifest)

- **Pros:** maximal consistency; trivial to implement.
- **Cons:** destroys intentional local customization (a stack bundle a repo needs);
  unsafe on a real multi-stack fleet. Rejected.

### C — Additive-only (local wins; standard only fills gaps)

- **Pros:** safest; never overwrites.
- **Cons:** the fleet never actually converges — local drift persists forever,
  defeating the purpose. Rejected.

## Consequences

### Positive

- Safe migration for repos that adopted Octopus on their own.
- The profile (D1) gives an objective test for "justified" local additions.
- De-escalation flagging prevents a standard from silently weakening a repo.

### Negative

- Requires a per-key diff/merge helper rather than a copy.
- "Arbitrary" local keeps still need a human decision (by design — surfaced, not
  auto-resolved).

### Risks

- Mis-classifying a justified local as arbitrary — mitigated by the declarative
  profile override in the fleet list.
