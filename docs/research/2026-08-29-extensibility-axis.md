# Research: extensibility-axis

**Date:** 2026-08-29
**Trigger:** Interview (`/octopus:interview`) — "does any role promote code
extensibility, SOLID, and refactoring heuristics that lead to design patterns?"

## Context

An audit of the role/skill surface answered the trigger question with a
qualified no. What exists is scattered and, on the abstraction axis,
one-directional:

- `architect` gates architecture (coupling, dependency direction, god objects,
  **premature abstractions**) but reviews; it does not teach refactoring.
- `mentor` teaches the *why* behind gate findings, but only reacts to findings
  another role already produced.
- `refactor-deepen` is the only real refactoring heuristic, and it runs the
  **opposite** vector: it hunts shallow modules and consolidates them.
- `audit-style` flags `over-engineering` — premature abstraction, speculative
  hierarchy, DRY-before-three — again anti-abstraction.
- `rules/common/patterns.md` is an *architectural* catalog (repository, service
  layer, Result, Null Object), not an object-pattern one.

SOLID is nearly absent as named vocabulary: only SRP (`coding-style.md:7-12`)
and DIP (`patterns.md:8-11`) appear; LSP, ISP and OCP appear nowhere, and the
sole literal mention of "SOLID" is in `test-tdd/SKILL.md:71`. No GoF pattern is
named anywhere.

Nothing detects the inverse failure: code so rigid that every extension costs a
multi-file edit. The gap was never a missing catalog — it was missing
**evidence**. The repo's posture is deliberately anti-over-engineering (YAGNI,
three-occurrences, the Deletion Test), so any skill that "promotes patterns"
collides with `audit-style` and `refactor-deepen` unless it is grounded in
measurement rather than taste.

## Analysis

The interview converged on one governing reframe: the trigger is **rigidity
under change**, not absence of a pattern. "A Strategy is missing here" is not a
finding; "every new provider edits the same 6 files" is.

Constraints resolved during the session, in order:

- **Evidence must be measured, not promised.** Churn and blast radius were
  chosen; roadmap/ADR-declared future change was rejected as speculation.
  This is what lets *maintainability outrank YAGNI* without licensing
  guesswork.
- **Determinism over model judgment.** Computing the evidence is arithmetic
  over `git log`; only interpretation needs a model. This mirrors the
  `code-metrics` contract (~0 tokens in the common case, LLM only on breach)
  and, notably, the same deterministic-over-non-deterministic decision the
  2026-06-06 `code-metrics` expansion made on every branch.
- **Must work where `code-metrics` does not.** The hard constraint: no
  `quality` bundle, no `lizard`/`madge`, no CI. This killed reuse of the
  `hotspots` metric (churn x complexity needs `lizard`) and any static
  import-graph fan-out. It does *not* rule out `cli/lib/`, which ships with the
  CLI core rather than per bundle.
- **Co-change over static fan-out.** Both were viable; co-change won because
  `git log` alone answers it, and because it proves the coupling repeatedly
  *cost* something rather than merely existing.
- **Measuring is not gating.** Placing the axis inside `audit-style` collided
  with that skill's signal-only contract. Resolved by separating the two roles:
  the audit reports evidence, `architect` classifies and blocks. This preserves
  ADR-002's split and keeps signal-only audits out of `audit-all`.
- **Blocking is symmetric.** Rigidity is usually pre-existing debt; blocking a
  PR for debt it did not create is how a gate loses the team. It blocks only
  when the diff *enlarges* the cluster — the same standard already applied to
  premature abstraction.

The unified ruler that falls out: **abstraction without co-change is premature
abstraction; co-change without abstraction is rigidity.** One measurement, two
opposite verdicts, one threshold — which also hardens the `over-engineering`
finding `audit-style` already emits.

A discovery reshaped the build cost: half the capability already exists.
RM-149 shipped `cm_git_churn()` (`git log --numstat`, configurable window),
and the per-file nominal data the gate needs is already computed into temp
files and discarded at `adapter-typescript.sh:241`. Exposing it is an output
change, not a new calculation.

Vocabulary was decided as **principle and pattern both named**, layered rather
than rival: Ousterhout's terms (Seam, Depth, Locality) describe the structure,
SOLID the force acting on it, the pattern the form. The binding rule that keeps
this from becoming cargo-cult: a pattern is never named without the evidence
that justifies it.

### Open questions (carry into the RM-184 spec)

- **Thresholds** — window length (`hotspots` uses 90 days), minimum co-change
  count, and minimum cluster size before a finding exists.
- **Ranking / per-PR ceiling** — the success criterion is findings about *the
  change*, not ambient debt; noise is the dominant failure risk.
- **Model tier** — `audit-style` runs on Haiku; naming principle and pattern may
  need to escalate, or be left to `architect` (opus), which also spreads the
  cargo-cult risk.
- **Degradation** — shallow clone truncates the churn window silently;
  `hotspots` answers `0` when tooling is missing, which for rigidity is a
  dangerous lie. Must report *unavailable*.
- **Finding shape vs. anchor verification** — a `rigidity` finding names a
  cluster of files, but `review-anchor` (`pr-review` Phase 4.5) verifies one
  `path:line` and demotes what it cannot resolve to QUESTION/`unanchored`.
  Working assumption: anchor on the diff file that enlarges the cluster, carry
  the remaining members as evidence. Noted as favourable: the Phase 4.55
  reflection prompt already instructs `keep` when a window cannot judge "a claim
  about coupling across files", so the reflection pass will not silently drop
  these.

## Identified Items

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| RM-184 | Extensibility axis — `git-signals` + `rigidity` finding + architect classification | 🔴 High | medium |
| RM-185 | Extract the layered-config resolver shared by `kr_*`, `cm_*` and `gs_*` | 🟡 Medium | low |

## Discarded Items

| Title | Reason |
|-------|--------|
| Static fan-out / import-graph blast radius | Needs a per-language parser (`madge`-class), breaking the "works without `code-metrics`" constraint. Also proves only that coupling exists, not that it cost anything. |
| Declared future change (roadmap/ADR) as trigger | Speculation, not measurement. Reopens the YAGNI argument the measured evidence exists to settle. |
| `architect` computing the evidence itself per PR | Non-deterministic and burns opus tokens on raw `git log` for every non-trivial PR. Measurement is arithmetic. |
| A standalone `refactor-extend` skill | Splits one ruler across two skills that must agree on thresholds and vocabulary forever — the exact incoherence the axis exists to remove. |
| `audit-style` emitting the merge verdict | Breaks its signal-only contract and the rule keeping signal-only audits out of `audit-all`. |
| A new artifact for readability | Already covered three times over (`audit-style`, native `simplify`, `code-metrics` v2 counters). Needs scope inclusion, not tooling. |
| Reusing `hotspots` directly | `churn x complexity` needs `lizard`; the constraint requires git-only. |
