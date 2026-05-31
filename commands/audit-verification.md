---
name: audit-verification
description: (Octopus) Signal-only verification audit — confronts a finished task against run evidence (unverified-completion-claim) and flags missing-file references (unresolved-reference). Queued by the zero-LLM verification-check Stop hook; runs cheap-tier on demand. Never blocks.
---

# /octopus:audit-verification

## Purpose

Surface the verification failure modes RM-088 deferred: a completion claimed
without the build/test/typecheck running, and a diff referencing a file the
build rejects. The recurring trigger is the deterministic `verification-check`
Stop hook (zero LLM); this skill is the on-demand, cheap-tier judgment.

## Usage

```
/octopus:audit-verification
```

Typically reached via `/octopus:review-proposals` against a queued
`*-verification.md` proposal. See `skills/audit-verification/SKILL.md` for the
findings, the cost contract, and the signal-only contract.
