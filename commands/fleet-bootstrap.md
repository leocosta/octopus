---
name: fleet-bootstrap
description: (Octopus) Converge a fleet of repos onto a layered Octopus standard (baseline + per-stack profile + adoption tier) from one fleet.yml — dry-run by default, non-destructive merge, never force-pushes.
---

# /octopus:fleet-bootstrap

Roll a standard across the fleet. Drives the `fleet-bootstrap` skill
(`skills/fleet-bootstrap/SKILL.md`) — do not reinterpret it here.

## Usage

```
/octopus:fleet-bootstrap                 # dry-run: preview the per-repo diff, write nothing
/octopus:fleet-bootstrap --apply         # write the merged .octopus.yml + run `octopus setup`
/octopus:fleet-bootstrap --apply --yes   # trusted batch, skip per-repo confirmation
/octopus:fleet-bootstrap --apply --pr    # open a guarded branch + PR per repo (never push main)
/octopus:fleet-bootstrap --from-audit <report>   # scope to repos audit-fleet flagged
```

## What it does

For each repo in `<workspace>/fleet.yml`'s `repos:`, it composes
`baseline ∪ profile(s) ∪ tier`, diffs against the repo's current
`.octopus.yml`, previews, and on `--apply` writes the merged manifest and
runs `octopus setup` (which seeds rules/hooks/agent-config/`.editorconfig`/
`.husky` per tier + detected stack).

Multi-stack and legacy are first-class: the standard is **layered** and
adoption is **phased** via tiers T0/T1/T2. Dry-run is the default; the
merge is per-key and non-destructive (arbitrary local keeps and tier
de-escalations are flagged, never silently removed); it never force-pushes.

Pairs with `/octopus:audit-fleet` (detect → remediate).
