---
name: council
model: sonnet
description: >
  Run one high-stakes decision through a council of 5 ephemeral advisor lenses
  that answer in parallel, peer-review each other anonymously, and get
  synthesised into a single verdict — agreements, clashes, blind spots, a
  recommendation, and the one thing to do first. Adapted from Karpathy's LLM
  Council. For genuine decisions with stakes and tradeoffs, not factual lookups
  or creation tasks.
triggers:
  paths: []
  keywords: ["council", "council this", "run the council", "war room",
    "pressure-test", "stress-test", "debate this", "should I X or Y",
    "which option", "I can't decide", "I'm torn between", "validate this decision"]
  tools: []
---

# Council — One Decision, Five Lenses, One Verdict

## Purpose

You ask one model a question, you get one answer with one blind spot — and no way
to see what it missed. The council runs the same decision through **five
independent thinking lenses**, has them **peer-review each other anonymously**,
then a **chairman** synthesises everything into a single verdict: where the lenses
agree, where they clash, what they all missed, the recommendation, and the one
thing to do first. Adapted from Andrej Karpathy's LLM Council — many advisors,
anonymous cross-review, one chairman.

The council is **read-only**: it reads the workspace to frame the question and
**writes nothing** unless you explicitly ask for a transcript.

## Invocation

```
/octopus:council <the decision or question>
/octopus:council --transcript <the decision or question>   # also save a transcript
```

It also auto-activates on the trigger phrases above — but only when the message
carries a **real decision with a tradeoff**, not a lookup or a creation task.

## When to convene the council

Good council questions — genuine uncertainty, multiple options, real cost of
being wrong:

- "Should I launch a paid workshop or a free course first?"
- "Which of these three positioning angles is strongest?"
- "I'm thinking of pivoting from X to Y — am I crazy?"
- "Here's my plan / landing page / architecture — what's weak?"

## When NOT to

Do not convene — answer directly instead:

- **Factual lookup** ("what's the capital of France") — one right answer.
- **Creation task** ("write me a tweet") — no judgment to pressure-test.
- **Trivial yes/no** with no real tradeoff ("should I use markdown").
- **Validation-seeking** where you already decided and just want a yes — the
  council will tell you what you do not want to hear; that is the point, but do
  not spend five lenses on a non-decision.

If a request looks trivial or factual, skip the council and just answer it.

## The five advisors

Five **thinking lenses**, not job titles. They are chosen to create three
built-in tensions, so the council disagrees productively instead of converging
too early.

1. **The Contrarian** — assumes the idea has a fatal flaw and hunts for it. Asks
   the questions you are avoiding. Not a pessimist — the friend who saves you from
   a bad deal.
2. **The First Principles Thinker** — ignores the surface question and asks "what
   are we actually trying to solve?" Strips assumptions, rebuilds from the ground
   up. Sometimes the most valuable output is "you're asking the wrong question."
3. **The Expansionist** — hunts the upside everyone else is missing. What could be
   bigger? What adjacent opportunity is hiding? Does not care about risk — cares
   about what happens if this works better than expected.
4. **The Outsider** — has zero context about you, your field, or your history, and
   responds only to what is in front of them. Catches the curse of knowledge:
   what is obvious to you but confusing to everyone else.
5. **The Executor** — only asks "can this actually be done, and what is the
   fastest path?" Ignores theory and strategy. If an idea sounds brilliant but has
   no clear Monday-morning first step, the Executor says so.

**The three tensions:** Contrarian ↔ Expansionist (downside vs upside), First
Principles ↔ Executor (rethink everything vs just ship), with the Outsider in the
middle keeping everyone honest.

**Boundary — ephemeral lenses, not roles.** The five advisors are **ephemeral
prompt-injected personas**, created fresh per session. The council creates **no
`roles/*.md` file** and reuses none. This is the opposite of `delegate`, which
dispatches **persisted** Octopus roles (`@architect`, `@security`, …). A lens is a
one-paragraph instruction overlaid on the model; a role is a full persisted
persona. Do not turn an advisor into a role file.

## Protocol

### Phase 1 — Frame (with context enrichment)

Before framing, **scan the workspace** for context that would let the advisors
give specific, grounded advice instead of generic takes — time-box it:

- `CLAUDE.md` / `claude.md` in the project root or workspace.
- Any `memory/` directory (audience, voice, past decisions).
- Files the user explicitly referenced or attached.
- Octopus-specific: `CONTEXT.md` (domain glossary) and `docs/adr/` if present.
- Prior `council-transcript-*.md` in the working directory, to avoid
  re-councilling settled ground.

Then **reframe** the raw question into one neutral prompt that all five advisors
receive: the core decision, key context (from the user and the workspace), and
what is at stake. Do **not** inject your own opinion or steer the answer. If the
question is too vague to council, ask **exactly one** clarifying question, then
proceed. Save the framed question — every later phase reuses it verbatim.

### Phase 2 — Convene (5 advisors in parallel)

Dispatch all five advisors **simultaneously** via
`superpowers:dispatching-parallel-agents`. Each sub-agent receives its lens
definition, the framed question, and this instruction: *respond independently, do
not hedge, do not try to be balanced, lean fully into your lens; if you see a
fatal flaw say it, if you see massive upside say it; 150–300 words, no preamble.*

**Degradation:** if `superpowers:dispatching-parallel-agents` is unavailable
(non-Claude-Code harness), fall back to **sequential** execution with a one-line
warning — output shape unchanged. In the sequential path, instruct each advisor
to ignore the other advisors' answers, since phase-1 independence can no longer be
guaranteed by isolation.

### Phase 3 — Anonymous peer-review (5 in parallel)

This is the step that makes the council more than "ask five times." Collect the
five responses and **anonymise** them as **Response A through E**, with the
advisor→letter mapping **randomised** so reviewers cannot defer to a favoured lens
— that anti-positional-bias step is the point.

Thread the anonymised **A–E** block into each of five reviewer prompts (truncate
any single response to ~4000 chars if long, as `delegate` does for pipeline
context). Each reviewer answers three questions, under 200 words, referencing
responses by letter:

1. Which response is strongest, and why?
2. Which response has the biggest blind spot, and what is it missing?
3. What did **all five** responses miss that the council should consider?

Same parallel-dispatch rule and degradation fallback as Phase 2.

### Phase 4 — Chairman synthesis

One agent receives the framed question, the **de-anonymised** phase-1 responses
(now labelled by advisor), and all five peer reviews. It produces the verdict in
this **fixed structure** — use these exact headings:

- `## Where the Council Agrees` — points multiple advisors converged on
  independently; these are the high-confidence signals.
- `## Where the Council Clashes` — the genuine disagreements. Do **not** smooth
  them over; present both sides and why reasonable advisors disagree.
- `## Blind Spots the Council Caught` — only what surfaced in the peer-review
  round; things individual advisors missed that others flagged.
- `## The Recommendation` — a clear, direct answer. Not "it depends." The chairman
  may side with a strong dissenter against the majority if the reasoning supports
  it, and must explain why.
- `## The One Thing to Do First` — a single concrete next step. Not a list. One.

## Presenting the verdict

Present the verdict directly in chat as markdown, headed
`## Council Verdict: <short topic>`, scannable, with bullets. **No HTML report and
no files by default** — Karpathy's visual HTML report is intentionally dropped to
honour Octopus's read-only / no-artifacts default.

## Transcript (opt-in)

Only on `--transcript` or an explicit request, write
`council-transcript-<slug>.md` in the working directory — `<slug>` is a kebab-case
phrase (~6 words) derived from the framed question. **No timestamp generated
inside the prompt** (Octopus prompt-skills cannot read the clock; if a date is
wanted, the CLI/git layer stamps it). The transcript contains: the framed
question, the five advisor responses, the A–E mapping, the five reviews, and the
final verdict.

## Anti-patterns

- Councilling a trivial, factual, or creation request — just answer it.
- Spawning advisors **sequentially** when parallel is available — early answers
  bleed into later ones and the lenses stop being independent.
- Skipping anonymisation in Phase 3 — reviewers then defer to favoured lenses
  instead of judging on merit.
- A hedged "it depends" recommendation — the whole point is the clarity one
  perspective cannot give.
- Creating a `roles/*.md` file for an advisor — advisors are ephemeral lenses.
- Writing any file when `--transcript` was not asked for.
- Letting the chairman (or you, while framing) inject an opinion into the framed
  question.

## Related

- `interview` — one-question-at-a-time grilling to **scope** a fuzzy problem into
  a concrete question; run it *before* the council when the decision is not yet
  sharp. Council pressure-tests a question that is already framed.
- `delegate` — dispatches **persisted roles** through a pipeline; council runs one
  question through **ephemeral lenses** and synthesises, rather than routing work.
- `consigliere-lens` — a single opinionated managerial frame over a grounded
  workspace; the council is five divergent frames over one decision.
