# Research — `audit-style`: a rules-aware semantic quality signal

- **Date:** 2026-06-02
- **Author:** Leonardo (Tech Manager II, ex-Staff SWE)
- **Roadmap:** seeds **Cluster 21** (RM-112)
- **Trigger:** A question — "is `/simplify` an Octopus feature?" It is not; `/simplify`
  is a native Claude Code skill (generic taste, applied to the diff, no project
  rules, no memory across runs). That raised the real question: **what could
  Octopus add around "simplify" that the native command structurally cannot?**

---

## The native `/simplify` and why it leaves a gap

The native `/simplify` reviews changed code for reuse, simplification, efficiency
and "altitude" cleanups, then applies fixes. It is good at generic taste. But by
construction it is **project-agnostic** (it does not load `rules/common/*` or the
active stack rules) and **memoryless** (no state across runs or repos). Octopus's
distinctive assets are exactly those two things: opinionated rules, the `audit-*`
family with severity reports, and the continuous-learning / knowledge loop.

So the defensible wedge is not to re-implement generic taste — Octopus would lose
on quality and duplicate the native — but to add the judgment the native cannot
make: **does this code honor the house rules, and is it over-engineered?**

## The missing third leg of the RM-088 triad

The RM-088 PRD is literally titled *"Local Guardrails: Quality, Style **&
Semantic Grounding**"* ([spec](../specs/local-guardrails-quality-style-grounding.md)).
It shipped two of three layers:

| Layer | Nature | Status |
|---|---|---|
| Syntactic block (`guardrails` bundle) | formatter, typecheck, secret scan, naming via existing rules | ✅ shipped (v1.69.0) |
| Semantic **grounding** signal (`audit-grounding`) | invented conventions, unsupported domain facts | ✅ shipped (v1.69.0) |
| Semantic **design/quality** signal | conformance to the *opinionated* design rules + over-engineering | ❌ never built |

The PRD treated "style/quality" as **syntactic** — formatter and naming via
existing rules, orchestrated by the pre-commit gate. The **semantic** judgment of
"does this code honor `exceptions.md` / `patterns.md`?" was never a deliverable.
The `audit-*` family today covers grounding, security, money, tenant, verification,
and config — but there is **no `audit-style`**. That is the gap, and it has an
exact sibling to mirror in shape: `audit-grounding`.

## Engine analogy: same shape, different source of truth

`audit-grounding` confronts the diff against the **domain** source of truth
(context doc, ADRs, knowledge base) and emits divergence findings. `audit-style`
is the same machine pointed at a **different source of truth — the rules**:
`rules/common/exceptions.md`, `patterns.md`, `coding-style.md`, plus the active
stack rules. Same signal-only discipline, same `quality` bundle, same severity
findings; only the reference set changes.

This satisfies the DRY threshold in `coding-style.md` from the other direction:
rather than a fourth bespoke reviewer, `audit-style` is the family's existing
review shape applied to the one source of truth not yet covered.

## What it judges (and what makes it un-native)

Findings are grounded in concrete rules, not generic taste:

- **Exceptions gate (G1/G2/G3)** — a custom exception with one throw site / zero
  catch sites, a wrapper that discards the cause, a speculative subtype hierarchy.
  These are semantic calls the native cannot make because it does not know the gate.
- **Result pattern vs throw** for expected failures inside a bounded context.
- **Boolean param → options object**, magic number → named constant, nested
  conditionals → guard clauses, layer separation (repository vs service).
- **Anti-over-engineering (the distinctive dimension, #2).** Premature abstraction,
  speculative subtype hierarchies, DRY applied before three occurrences. This is
  the sharp twist: where the native optimizes for "less code" and may *introduce*
  abstraction, `audit-style` knows the rules that say abstraction is a cost — so it
  is the one reviewer that flags **when not to simplify**.

## Decisions taken in this session

- **Positioning:** `audit-style` as a sibling of `audit-grounding` — not a
  `simplify` wrapper. It registers in the `quality` bundle (no loose skill) and is
  orchestrated by `codereview` / `pr-review` / `implement`. Like `audit-grounding`
  and `audit-verification`, it is **not** part of `audit-all`'s parallel dispatch —
  `audit-all` is a fixed composer of the four domain code audits (security, money,
  tenant, contracts); the signal-only semantic audits run via the review flows.
  Native `/simplify` keeps doing generic taste; `audit-style` adds the house-rules
  layer on top — division of labour, not competition.
- **Trigger:** **skill-only**, no new Stop hook. It runs when the review/implement
  flows invoke it (like `audit-money` / `audit-tenant`), keeping session noise low.
  (`audit-grounding`/`audit-verification` ship recurring hooks; `audit-style` does
  not — deliberately, to avoid a per-session cost for a quality signal.)
- **Knowledge loop (#3): reuse, no new RM.** Recurring `audit-style` findings feed
  the existing `continuous-learning` / `review-proposals` / `propose-knowledge-update`
  loop (and RM-093 at the team level) to become rule / CLAUDE.md candidates. This
  is the manager-multiplier payoff — but it is wiring into existing machinery, not
  a separate deliverable.
- **Signal, never block.** Per the RM-088 principle: the syntactic gate blocks at
  commit because it is objective; a probabilistic design verdict must only signal.

## Distinction from neighbours

| Tool | Role |
|---|---|
| native `/simplify` | generic taste, **applies** fixes, no rules, no memory |
| `guardrails` (syntactic) | **blocks** at commit on formatter/typecheck/secret |
| `audit-grounding` | semantic signal vs **domain** source of truth |
| `refactor-deepen` | **deepens** design (improves architecture) |
| **`audit-style` (new)** | semantic signal vs **rules** source of truth + over-engineering |

---

## Items

### RM-112 — `audit-style` skill (rules-aware semantic quality signal)

**Need:** a semantic, signal-only reviewer that confronts the diff against the
opinionated design rules (`rules/common/exceptions.md`, `patterns.md`,
`coding-style.md` + active stack rules) and emits severity-tiered divergence
findings — including an explicit **over-engineering / anti-over-simplify**
dimension (premature abstraction, speculative hierarchy, DRY-before-three). Mirrors
`audit-grounding`'s shape and tests (the "deep module" carries scenario coverage:
a rule-violating diff produces a finding; a speculative abstraction produces a
finding; rule-conformant code produces none). Registers in the `quality` bundle,
orchestrated by `codereview` / `pr-review` / `implement` (not part of `audit-all`'s
domain dispatch). No new Stop hook. Recurring findings reuse the existing
continuous-learning loop.

**Problem it solves:** the only `audit-*` source of truth never covered is the
house rules themselves; the native `/simplify` cannot enforce them (no rules, no
memory) and can even introduce the over-abstraction the rules forbid. Closes the
deliberately-deferred "Quality/Style" leg of the RM-088 triad.

## Discarded Items

| Item | Reason |
|---|---|
| `octopus:simplify` wrapper (native + rules) | Mixes apply-fix with signal and breaks the `audit-*` pattern; native already owns generic taste. Rejected in favour of `audit-style` sibling. |
| New Stop hook (`style-check`) | Per-session cost for a quality signal not justified; skill-only orchestrated by the review flows is enough. |
| Standalone knowledge-loop RM | Duplicates `continuous-learning` / `review-proposals` / RM-093; folded in as reuse, not a deliverable. |
| Cross-repo fleet hotspot aggregation | Manager-multiplier expansion overlapping RM-093 / `audit-fleet`; out of scope for this lean cut. |
