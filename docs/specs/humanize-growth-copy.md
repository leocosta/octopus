# PRD: Humanize growth copy

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-08-02 |
| **Status** | Ready for agent |
| **Roadmap** | RM-167, RM-168, RM-169 (Cluster 30) |
| **Reference** | [blader/humanizer](https://github.com/blader/humanizer) — 33 patterns, derived from [Wikipedia:Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) |

## Problem

Copy produced by the growth bundle reads as machine-written to its audience. This was
reported from outside the project, which matters: the failure is visible to readers
without any knowledge of how the copy is made.

The cause is not an absence of voice governance. The shared substance-voice gate and
its lint already exist and work — but they police a different axis. They target hype,
superlatives and manufactured urgency. What marks the copy as generated is a separate
family of signals: significance inflation, copula avoidance, superficial participle
tails, negative parallelisms, forced triads, bolded inline headers, and a small set of
high-frequency vocabulary. None of those is hype, so none of them fires the gate.

A sample carrying more than a dozen of these signals returns a clean report from the
lint today. The gate cannot see the problem being reported.

Worse, two of the signals are not model drift at all — the channel templates **mandate**
them. Every LinkedIn post carries exactly three bullets, every Instagram caption exactly
three values, every landing page exactly three, because the form provides exactly three
slots. The Instagram caption ships a decorative check-mark glyph on every line. No
prompt-level instruction can avoid a pattern the form requires.

## Solution

Add a second voice axis alongside the existing one rather than widening it, since the
two catch different failures and should stay separately diagnosable. A new shared
fragment states the anti-tell rules; the existing lint grows a second pattern class
that reports under its own label. The channel templates stop hardcoding the triad and
the glyph, and the single post skeleton loosens so structure varies between channels
and launches. Finally, each launch skill gains an adversarial audit step before the kit
closes — a second, sceptical pass over drafted copy, which is what a single generative
pass reliably fails to do.

## User Stories

- As a **marketer publishing a feature launch**, I get copy whose bullet count varies
  with what there is to say, so posts across a quarter do not share one silhouette.
- As a **marketer**, I see hype findings and AI-tell findings reported separately, so I
  know which kind of revision a line needs.
- As a **developer reading a launch post**, I encounter mechanism and numbers rather
  than significance claims, and nothing tells me the text was generated.
- As a **maintainer running the lint in strict mode**, a text carrying AI tells but no
  hype fails the gate, where today it passes.
- As a **maintainer**, the anti-hype rules keep behaving exactly as before, so the
  addition cannot regress the axis that already works.
- As a **repo owner overriding voice locally**, I can override the anti-tell fragment
  the same way I override the substance one, through the documented marketing override
  path.
- As an **agent generating a launch kit**, I am asked what makes the draft look
  AI-generated and I revise before the kit closes, rather than shipping the first pass.
- As a **contributor editing a channel template**, a test fails if I reintroduce a fixed
  third slot or a hardcoded glyph.

## Implementation Decisions

These are settled; the agent should not reopen them.

1. **A sibling fragment, not an extension of the existing one.** Hype and AI-tells are
   independent axes. Merging them would make a finding ambiguous and would risk
   disturbing rules that currently work.
2. **The existing anti-hype rules are untouched.** That axis is solved. This work is
   purely additive.
3. **The lint reports the two classes under separate labels.** Same scan mechanics, same
   strict mode, same file-and-line reporting — only a second pattern set and a label.
4. **Regex is the right tool for the tell class.** These constructions are as
   detectable as hype vocabulary. The fragment carries the judgement calls; the lint
   carries the mechanical ones.
5. **Templates move to a variable bullet count**, with an instruction to vary it per
   post, instead of three fixed slots. The decorative glyph is removed rather than
   made configurable.
6. **The post skeleton becomes guidance, not a form.** A post may open on the number, on
   the objection, or on a flat sentence. Uniform structure across every channel is
   itself a tell, distinct from any single pattern.
7. **The audit step uses the reference catalogue's literal question** — asking what
   makes the draft obviously AI-generated, answering briefly, then revising. The value
   is that the second pass is adversarial rather than generative.
8. **Order of work: templates first.** The form mandates the pattern, so no rule about
   it can hold until the slots are gone. The audit step comes last, since it needs the
   fragment's vocabulary to audit against.
9. **The reference catalogue is the upstream 33-pattern set**, not the locally installed
   copy, which is smaller and omits the persuasive-prose patterns that matter here.
10. **Scope is the subset that bites in product copy** — significance inflation, copula
    avoidance, negative parallelism, participle tails, bolded inline-header lists, the
    high-frequency vocabulary, forced triads, and generic positive conclusions. The
    remaining patterns from the catalogue are not carried over.

## Testing Decisions

No new suite is created; three existing ones absorb the work.

- **The lint suite** gets behavioural coverage of the tell class: the sample that
  currently returns clean must fail, each pattern family gets a positive case, and the
  existing hype cases must keep passing unchanged. Strict mode is exercised for the new
  class. This is the deepest coverage in the change because the lint is the only
  deterministic component.
- **The launch-feature suite** gets structural assertions that no channel template
  carries a fixed third slot or a hardcoded glyph. This is the regression guard for the
  defect that motivated the work — without it, a future template edit silently restores
  the triad.
- **The feature-to-market suite** covers wiring: the new fragment exists, both launch
  skills reference it, and the audit step is present in each.

Structural rather than behavioural assertions are correct for the templates and skills
because both are prompt artifacts with no runtime to exercise, which is the convention
already used across the skill suites.

## Out of Scope

- **Voice calibration from writing samples.** The reference catalogue learns a user's
  style from real samples. Growth templates carry a voice-source field but nothing that
  learns from examples. Worth its own item; not part of this one.
- **The image and video skills in the growth bundle.** Their output is visual; this work
  is about prose.
- **Rewriting already-published copy.** This changes generation, not history.
- **Retiring or weakening any anti-hype rule.**
- **A second call site for the audit step outside the launch skills.**

## Further Notes

Questions the agent should raise before starting rather than guessing:

- The high-frequency vocabulary list needs a judgement call on borderline entries. Some
  words in the catalogue are legitimate in technical copy, and flagging them would
  train maintainers to ignore the lint. Propose the list before wiring it in.
- Portuguese equivalents are undecided. The anti-hype patterns cover both languages;
  whether the tell class needs the same treatment depends on whether the generated
  Portuguese exhibits the same constructions, which has not been checked.
- The variable bullet count needs a floor and a ceiling. Two to four is the assumption;
  confirm before applying it across every channel.
