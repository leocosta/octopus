---
name: steelman
description: (Octopus) Build the strongest case against your own position — the best evidence, the most competent critic — then show what actually bites and what you would have to believe for your position to survive.
---

# /octopus:steelman

## Purpose

Test a position you already hold by constructing the **best** argument against it,
not the easiest one. Returns the maximal opposing case, which parts of it genuinely
bite, the beliefs your position depends on, and what you can concede without losing
the thesis. Read-only.

## Usage

```
/octopus:steelman <the position you are defending>
```

**Examples:**

```
/octopus:steelman we should split the fulfillment service out of the monolith
/octopus:steelman rewriting the checkout in-house beats buying a provider
```

## Instructions

Invoke the `steelman` skill (`skills/steelman/SKILL.md`). The skill owns the full
six-step protocol (extract the position → find the genuine opposition → build the
maximal case → separate what bites → survival test → two buckets) — do not
reinterpret it here.

Note the boundary: this builds the opposing side's case **up**. Attacking the user's
idea to find its flaws is `council`'s Contrarian lens, not this command.
