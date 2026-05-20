---
name: interview
description: >
  Interactive requirements interview — one question at a time, walking
  the decision tree of a new feature or problem until shared
  understanding is reached. No dependency on CONTEXT.md or docs/adr/.
  Produces a summary the user confirms, ready as input for doc-align,
  doc-prd, or implement. The greenfield counterpart to doc-align (which
  validates an existing plan against existing docs).
---

# Requirements Interview

## Overview

`interview` is the **greenfield** grilling skill. It runs when the
user has an idea or a problem but no plan yet — no CONTEXT.md to
align against, no ADRs to consult, just intent waiting to be made
concrete. The skill walks the decision tree one question at a time
until the intent is shaped enough to feed the next step
(`doc-align`, `doc-prd`, or `implement`).

This skill is *flexible* — questions adapt to the user's answers,
not to a script.

## When to Engage

Engage when the user wants to:

- Shape a new feature or problem from scratch
- Pin down requirements before any design work
- Untangle a vague ask ("we need something for X") into a concrete
  set of decisions

Do **not** engage when:

- A plan already exists and needs validation — use `doc-align`
- The decisions are already in context from a prior session — use
  `doc-prd` to synthesise directly
- The user is exploring options open-endedly with no commitment to
  converge — use `superpowers:brainstorming` if installed

## interview vs. doc-align — the boundary

| Skill | Pre-condition | Output |
|---|---|---|
| `interview` | No plan, no docs needed | A confirmed intent summary |
| `doc-align` | A plan exists, CONTEXT.md / ADRs exist | An aligned plan + lazy CONTEXT.md / ADR updates |

The natural flow is `interview → doc-align → doc-prd → implement`.
`interview` establishes; `doc-align` validates; `doc-prd` packages;
`implement` executes.

## Protocol

### Step 1 — Anchor on the user's stated goal

Restate the goal in one sentence and get explicit confirmation
before asking anything else. This is the **root** of the decision
tree — every question after this is a branch off of it.

Examples of root statements:

- "Build a way for parents to see their child's enrollment status."
- "Reduce the time it takes to onboard a new tenant from 3 hours to
  under 30 minutes."
- "Fix the fact that refunds sometimes leave the customer in a
  half-paid state."

If the user cannot state a root in one sentence, the first questions
target the root, not branches.

### Step 2 — Ask one question at a time

Each question targets exactly **one** of:

- **A constraint** — what must be true (budget, deadline, scale,
  regulation)
- **An actor** — who does this, who reads this, who pays for this
- **A boundary** — what is included vs. excluded
- **A trade-off** — which of two viable options the user prefers
- **A success criterion** — how the user will know the work is done

Never batch questions. Never ask "and also…" tacking on a second
question to soften the first. The user's answer reshapes the tree;
batched questions miss the reshape.

### Step 3 — Prefer open-ended over yes/no

Yes/no questions confirm what you already suspect. Open-ended
questions surface what you do not know to ask. Default to open-ended
unless the tree is narrowing to a binary at the end.

Bad: "Should this be admin-only?"
Good: "Who needs to do this, and what changes for them if everyone
can do it vs. only admins?"

### Step 4 — Track the tree visibly

Every 3–5 questions, output a short recap:

```
**Established so far:**
- Actor: <…>
- Constraint: <…>
- Out of scope: <…>

**Still unresolved:**
- <branch the next question targets>
```

This is the same shape as `triage-issues`'s `needs-info` notes — it
preserves the interview's progress so a handoff or interruption does
not erase it.

### Step 5 — Recognise tree resolution

The interview is done when:

- Every branch the user named has an answer
- The trade-offs are all decided (no "we'll figure it out later")
- The success criteria are concrete enough to test against
- The user can read the summary and say "yes, that is what I want"

Do not extend the interview past resolution to "be thorough" — the
goal is concrete intent, not exhaustive coverage.

### Step 6 — Output and hand off

Produce a final summary:

```
## <root statement>

### Actors
- <…>

### Constraints
- <…>

### In scope
- <…>

### Out of scope
- <…>

### Trade-offs decided
- <decision>: chose <option A> over <option B> because <reason>

### Success criteria
- <…>

### Open questions for the next step
- <…>
```

Then suggest the next skill:

- Existing CONTEXT.md and the work touches documented terrain → `doc-align`
- Decisions are concrete and the work is ticket-sized → `doc-prd`
- Decisions are concrete and the work starts immediately → `implement`

## Anti-Patterns

- Multiple questions per turn, including "and also…" hedges
- Yes/no questions when the tree branch has more than two outcomes
- Skipping to solution-design before the constraints are pinned
- Restating the user's answer in your own words and asking them to
  confirm the restatement — that wastes a turn; ask the next real
  question
- Continuing past resolution to add "just one more"
- Producing a summary without explicit user confirmation of the root
  statement first

## Integration with Other Skills

- **`doc-align`** — runs *after* `interview` when CONTEXT.md / ADRs
  exist and the established intent needs to be validated against
  them
- **`doc-prd`** — runs *after* `interview` when the established
  intent is ticket-sized and ready for an AFK agent
- **`implement`** — runs *after* `interview` when the work starts
  immediately and the intent summary is enough plan
- **`superpowers:brainstorming`** — sibling territory when the
  plugin is installed; that skill is broader exploration,
  `interview` converges on concrete intent
- **`triage-issues`** — borrows the "Established so far / Still
  unresolved" recap format from this skill
