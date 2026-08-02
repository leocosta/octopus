# Human Voice (shared)

> The anti-tell gate for generated copy — sibling to `substance-voice.md`.
> Override at `docs/marketing/human-voice.md` in the target repo.

## Why this is separate

`substance-voice.md` polices **hype**: superlatives, FOMO, manufactured urgency.
This file polices a different failure — copy that is honest, evidence-backed, free
of hype, and still visibly machine-written.

The two axes are independent. A passage can clear the substance gate completely
and announce itself as generated in its first sentence. Keep the findings
separate: a hype hit and a tell hit call for different revisions.

Source: [Wikipedia's Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing),
via the [humanizer](https://github.com/blader/humanizer) catalogue.

## The tells

### Significance inflation

Do not claim that a thing represents, marks, or contributes to something larger.
No `a testament to`, `marks a pivotal moment`, `a key milestone in the evolution
of`, `underscores its importance`, `reflects a broader shift`.

State what shipped. The reader decides whether it is significant.

### Copula avoidance

Use `is`, `are`, `has`. Not `serves as`, `stands as`, `boasts`, `features a`,
`represents`. "Smart Sync is the sync engine" beats "Smart Sync serves as the
foundation for syncing".

### Participle tails

Do not bolt an `-ing` clause onto a finished sentence to add depth:
`…, underscoring our commitment`, `…, ensuring reliability`, `…, reflecting the
team's focus`, `…, fostering trust`. Cut the clause or make it its own sentence
with a subject.

### Negative parallelism

No `not just X — it's Y`, `it's not merely A, it's B`, `more than just`. Say the
thing directly. This construction promises depth and delivers a restatement.

### Forced triads

Three is not a magic number. Write the count the feature has: two, four, or one
line with no list. See the bullet-count note in the caption templates — the
templates no longer impose three, so nothing else should either.

### Bolded inline headers

Not `- **Speed:** Requests are faster.` in a list where every item follows the
same shape. Write the sentence, or use a real heading.

### Vocabulary

Avoid: `delve`, `intricate`, `testament`, `pivotal`, `crucial`, `vital`,
`tapestry`, `realm`, `underscore`, `foster`, `showcase`, `robust`, `holistic`,
`myriad`, `nuanced`, and `Additionally,` as a sentence opener.

Legitimate in technical copy and therefore **not** banned: `key` (API key, key
rotation), `critical` (critical path), `align` (align with the spec), `highlight`
(highlight a row), `enhance` when describing an actual improvement.

### Generic positive conclusions

Do not end on `the future looks bright`, `exciting times ahead`, `a major step
forward`, or `we can't wait to see what you build`. End on the concrete: what
ships next, or nothing at all.

### Formulaic challenge sections

No `Despite these challenges, X continues to thrive`. If there is a limitation,
name it and say what is being done.

## Portuguese

Not a translation of the list above. Portuguese has its own tells, and some of
the strongest have no English equivalent.

- **Reflexive copula avoidance** — `se destaca como`, `se consolida como`,
  `configura-se como`, `atua como`. Use `é`.
- **Linking gerunds** — a gerund clause bolted onto a finished sentence:
  `…, garantindo mais confiabilidade`, `…, visando reduzir custos`,
  `…, proporcionando uma experiência melhor`. This is the PT participle tail, and
  it is far more frequent in generated Portuguese than its English counterpart.
- **Signposting connectives** — `Nesse sentido,`, `Dessa forma,`, `Por sua vez,`,
  `Vale ressaltar que`, `Cabe destacar que`. They announce a transition instead
  of making one.
- **Significance inflation** — `desempenha um papel fundamental`, `um marco
  importante`, `um divisor de águas`, `momento decisivo`.
- **Negative parallelism** — `não apenas X, mas também Y`, `não se trata de X, e
  sim de Y`.
- **Generic conclusions** — `o futuro é promissor`, `um grande passo`,
  `Apesar desses desafios…`.

**The word is not the problem; the position is.** `garantir`, `destacar`,
`fundamental` and `robusto` are ordinary in Brazilian technical writing.
"Garanta a consistência antes da migração" is fine. "…, garantindo a
consistência" tacked onto a complete sentence is the tell. Judge the
construction, never the bare word.

## Structural tells

Individual sentences can be clean while the shape gives it away.

- **Uniform rhythm** — every sentence the same length. Vary it. Short ones land.
- **Identical post silhouette** — if a reader sees three of your posts and can
  predict the fourth's structure, the structure is the tell.
- **Symmetry** — perfectly balanced sections and evenly weighted bullets read as
  assembled. Real emphasis is uneven.

## The audit pass

A single generative pass leaves tells in, because the model producing the copy is
the model that produced the tells. Before publishing, ask explicitly:

> What makes this obviously AI-generated?

Answer it in a few words, then revise. The value is that the second pass is
adversarial rather than generative.

## What this does not license

Voice is not an excuse to invent. The no-fabrication rule from
`substance-voice.md` still holds: never invent a number, a quote, a customer, or
a benchmark to make copy sound more human.
