---
name: context-handoff
description: >
  Compact the current conversation into a handoff document another agent can
  pick up — with a suggested-skills section, saved to the OS tmp dir (not the
  workspace), referencing existing PRDs/plans/ADRs/issues/commits by path
  rather than duplicating, with mandatory redaction of secrets and PII.
---

# Conversation Handoff

## Overview

When work needs to continue in a new session — different agent,
different model, different time-of-day, fresh context window — a
handoff document carries forward what matters without polluting the
repo. This skill writes that document.

The handoff is **prescriptive**, not just descriptive. It tells the
successor which skills to invoke, which files to read, and which
decisions are already settled.

## When to Engage

Engage when:

- The user says "handoff", "compact this", "another agent should pick
  this up"
- The context window is near its limit and the work is not finished
- A `/octopus:delegate` call is about to be made and the delegate
  needs more than the immediate task

Do **not** engage when:

- The session is finishing cleanly and the next step is a commit / PR
  (the commit message + PR body are the handoff)
- The work is fully captured in a PRD / spec already — point at the
  doc, no second copy needed

## Where the Handoff Lives

Save to the **OS temp directory**, not the workspace.

- Linux / macOS: `$TMPDIR` or `/tmp/octopus-handoff-<timestamp>.md`
- Windows: `%TEMP%\octopus-handoff-<timestamp>.md`

Reasons: handoffs are session ephemera, not project artifacts — they
should not show up in `git status`. A handoff that lives in the repo
will be read months later as if it were canon, and it is not. The
successor agent receives the path explicitly; tmp is fine.

If the user explicitly wants the handoff committed (rare), that is a
PRD or a spec — route to `doc-prd` or `/octopus:doc-spec`.

## Protocol

### Step 1 — Summarise the session

A short narrative: what was attempted, what was decided, what is
in-flight, what is blocked.

### Step 2 — List durable references

For every artifact already produced in the repo, link by path/URL —
**do not duplicate content**: PRDs (`docs/rfcs/*`), plans
(`docs/plans/*`), ADRs (`docs/adr/*`), specs (`docs/specs/*`),
issues / PRs (URL), commits (SHA).

If a reference is missing — a decision was made in chat but never
written down — flag it. The handoff is **not** the durable record;
it should *point at* the durable record.

### Step 3 — Write "Suggested next skills"

A prescriptive section. For the remaining work, list the skills the
successor should invoke, in order:

```
**Suggested next skills:**
1. `test-tdd` — write the regression test for the auth-refresh bug
2. `debug` — Phase 4 documentation once the fix is green
3. `audit-security` — pre-merge audit
```

This is the handoff's most valuable section. Without prescription
the next agent re-discovers tools.

### Step 4 — Redact

Before writing, scrub: tokens, API keys, passwords (replace with
`<REDACTED>`); personal data (emails, names, IDs unless the successor
needs them); internal URLs that include session identifiers. The
handoff lives in tmp, but tmp is on a shared filesystem.

### Step 5 — Output the path

Tell the user the absolute path of the handoff file. The successor
agent will read it from there.

## Anti-Patterns

- Saving the handoff inside the workspace
- Duplicating content that exists in a PRD / plan / ADR / issue —
  reference, do not copy
- Omitting "Suggested next skills"
- Writing without the redaction pass
- Handoffs longer than two screens — if longer, the work was
  transcribed, not summarised

## Integration with Other Skills

- **`context-budget`** — sibling in the `context-*` family.
  `context-budget` measures, `context-handoff` exits
- **`delegate`** — when the next agent is an Octopus role, the
  delegate invocation includes the handoff path as input
- **`doc-prd`** — when the handoff would have been long because the
  work is genuinely ticket-sized, route to `doc-prd` instead
- **`continuous-learning`** — recurring patterns surfaced during the
  session get filed in `knowledge/` *before* the handoff is written,
  not described inside it
