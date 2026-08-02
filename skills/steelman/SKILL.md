---
name: steelman
model: sonnet
description: >
  Build the strongest possible version of the argument against your own position —
  the best evidence, the best framing, the most competent critic who would plausibly
  exist — then show which parts actually bite and what you would have to believe for
  your position to survive. Constructs the opposing case rather than attacking yours;
  for attacking, use council's Contrarian. Standalone, and invoked by doc-adr before
  an alternative is rejected. Read-only.
triggers:
  paths: []
  keywords: ["steel man", "steelman", "strongest counterargument",
    "best case against", "argue the other side", "where is my reasoning weak",
    "poke holes in this", "what am I missing"]
  tools: []
---

# Steelman — The Best Case Against You

## Overview

Most critique arrives weaker than it should be. A reviewer is being polite, a
counter-argument is a strawman that was easy to knock down, or you have already
rehearsed the rebuttal. None of that tells you whether your position holds.

This skill constructs the **strongest** version of the opposing case — the one a
genuinely competent critic would make — and then locates where your reasoning is
actually load-bearing. The output is not a verdict on who is right. It is a sharper
version of the disagreement, so you can answer the part that matters.

**Read-only.** It reads to understand the position and writes nothing.

## When to Engage

Engage when there is a **position being defended** and the user wants it tested:
before committing to a technical direction, when a decision feels too easy, when the
opposition so far has been weak, or before rejecting an alternative in an ADR.

Do **not** engage for:

- **A question with an answer** ("does Postgres support partial indexes") — there is
  no position to steel-man.
- **A decision between options with no stated position** — that is `council`, which
  weighs several options at once. Steel man tests one position you already hold.
- **Attacking an idea to find its flaws** — that is `council`'s Contrarian lens. This
  skill builds the other side's case *up*; it does not tear yours down.

## Protocol

### Step 1 — Extract the real position

What is being defended is rarely what was stated. "We should use Kafka" usually
defends something like "our consumers need replay and we will have more of them."
State the position in one sentence and **confirm it with the user if the gap is
material** — steel-manning a position they never held makes everything downstream
noise.

### Step 2 — Find the genuine opposition

The strong contrary, not the convenient one. A **strawman** is the version that is
easy to defeat; it is the default failure of this exercise and the reason most
"considered alternatives" are worthless. Ask who actually disagrees with this in
practice, and what they know that makes them disagree.

### Step 3 — Build the maximal case

Write the opposing argument as its **best evidence** and best framing would have it,
from the **most competent critic** who would plausibly exist. Grant it every
reasonable assumption. Do not hedge it, do not pre-rebut it, and do not signal that
you disagree — a steel man that telegraphs its own weakness is a strawman wearing
better clothes.

### Step 4 — Separate what bites from what is rhetoric

Not every strong point is lethal. Sort the case into the points that would genuinely
change the decision if true, and the points that are merely well-argued. Say which is
which. A steel man that lands everything is flattering the opposition, not testing it.

### Step 5 — The survival test

Ask: **what would you have to believe for your position to still stand?** Name those
beliefs explicitly. This is where the real weakness surfaces — usually as an
assumption that was never examined because it never had to be stated.

### Step 6 — Return two buckets

Close with exactly two lists:

- **Demands an answer** — the points that must be addressed for the position to hold.
- **Can be conceded** — the points that are correct but do not cost the thesis.
  Conceding these is what makes the remaining position defensible rather than
  stubborn.

## Output

Present in chat as markdown under `## Steel Man: <the position>`, with the maximal
case first, then what bites, then the survival test, then the two buckets. No files
are written.

## Anti-Patterns

- **Strawmanning under a steel-man label** — the single most common failure. If the
  opposing case is easy to answer, it was not built at maximum strength.
- **Capitulating** — conceding the whole thesis. The point is to sharpen a position,
  not abandon it; a steel man that ends in "you're wrong" skipped step 4.
- **Attacking instead of constructing** — hunting for flaws in the user's position is
  the Contrarian's job in `council`. This skill argues *for* the other side.
- **Steel-manning a position the user never held** — step 1 skipped, everything after
  it wasted.
- **Hedging the maximal case** — pre-rebutting inside step 3, so the argument arrives
  already defeated.
- **Ending without the survival test** — the two buckets without the beliefs behind
  them is a debate summary, not a diagnosis.

## Integration with Other Skills

- **`council`** — five divergent lenses over one decision, with a chairman verdict.
  Its Contrarian *attacks* an idea; this skill *builds* the opposing case. Use
  `council` when you have options to weigh, `steelman` when you have a position to
  test. `council --pre-mortem` is the third member of that family: it assumes failure
  has already happened.
- **`doc-adr`** — the one call site. `## Alternatives Considered` degrades to chaff
  when a rejection is recorded without the alternative's strong form; `doc-adr`
  invokes this protocol inline before an alternative is seriously rejected.
- **`respond-to-review`** — deliberately *not* wired. It already separates reasoned
  critique from preference, and PR feedback is not where the extra step belongs.
  Invoke `steelman` standalone if a review thread warrants it.
- **`interview`** — scopes a fuzzy problem into a concrete question. Run it first when
  there is no clear position yet; steel man needs one to push against.
