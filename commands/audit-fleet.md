---
name: audit-fleet
description: (Octopus) Cross-repo adoption + drift audit — reports each repo's Octopus config against its declared target (baseline + stack profile + adoption tier) from fleet.yml. Signal-only; feeds fleet-bootstrap --from-audit.
---

# /octopus:audit-fleet

Report adoption and drift across the fleet. Drives the `audit-fleet`
skill (`skills/audit-fleet/SKILL.md`) — do not reinterpret it here.

## Usage

```
/octopus:audit-fleet                 # audit the fleet from fleet.yml (or a discovered list)
/octopus:audit-fleet <path> ...      # audit an explicit list of local repo paths
```

## What it does

Resolves the fleet (primarily from `<workspace>/fleet.yml`), computes each
repo's target (`baseline ∪ stack profile ∪ adoption tier` — the same
composition `fleet-bootstrap` applies), and inspects each repo's actual
Octopus surface against it: adoption tier, profile/bundles, Octopus version,
rules drift, and `CONTEXT.md`/ADR adoption.

Produces a **signal-only** report: a per-repo table (target vs actual + drift
flags) and a drift-hotspots rollup (the widest gaps first). It never mutates a
repo — to remediate, run `/octopus:fleet-bootstrap` (which can consume this
report via `--from-audit`).

The cross-repo analog of `/octopus:audit-config`.
