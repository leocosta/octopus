# ADR-012: rigidity evidence — a signal-only audit measures, the gate role blocks

## Status

Accepted — 2026-08-29

## Context

The review surface has an asymmetry. `audit-style` already owns one half of a
design ruler — its `over-engineering` finding covers premature abstraction,
speculative hierarchies and DRY-before-three — but nothing owns the opposite
half: code that is *rigid*, where every extension pays a toll across several
files. The half was missing because the evidence was missing; judging rigidity
by taste is precisely what makes a reviewer easy to ignore.

An interview (`/octopus:interview`, 2026-08-29) scoped the axis and resolved
the governing constraint: it must work in repos that have **not** adopted the
`quality` bundle, have no `lizard`/`madge` installed, and run no CI — which
rules out reusing the `code-metrics` `hotspots` metric (churn x complexity)
and any static import-graph analysis. It also set the trade-off explicitly:
maintainability outranks YAGNI, but only when backed by measurement.

## Sources

- `docs/research/2026-08-29-extensibility-axis.md` — the interview record.
- `skills/audit-style/SKILL.md` — the signal-only contract and the
  `over-engineering` finding this pairs with.
- `roles/architect.md` — Phase 2 severity classification, and the existing
  `premature abstractions` approval criterion.
- `docs/adr/002-mentor-vs-architect-teach-mode.md` — gating and teaching are
  separate concerns; this ADR extends the same split to measuring.
- `cli/lib/code-metrics-lib.sh:435-461` — `cm_git_churn` / `cm_hotspot_count`,
  the existing git-history capability (RM-149).
- `cli/lib/commands.default` — the CLI command registry.

## Decision

Split **measuring** from **gating** for the extensibility axis:

1. A new `cli/lib/git-signals.sh`, dispatched as `octopus git-signals`,
   computes two **git-only, stack-agnostic** signals: per-path churn and
   co-change clusters (files that repeatedly change in the same commit).
   `cm_git_churn` moves here and `code-metrics` consumes it, so `hotspots` is
   unchanged.
2. `audit-style` gains a third finding type, `rigidity`, carrying the hard
   evidence (cluster members, co-change count, and whether the diff *adds* a
   member). It stays **signal-only** — its contract is untouched.
3. `architect` consumes the finding and classifies it: `ADVISORY` by default,
   `BLOCKING` only when the diff enlarges the cluster.
4. `mentor` names the principle (SOLID) and the pattern (GoF) in its teaching
   unit, always bound to the evidence that justifies it.

This makes the ruler symmetric and single: **abstraction without co-change is
premature abstraction; co-change without abstraction is rigidity.** Both sides
charge the author only for what the diff itself introduced.

## Alternatives Considered

### A — `audit-style` emits the merge verdict itself

- **Pros:** one place owns the whole ruler; no finding hand-off to parse.
- **Cons:** breaks the skill's stated signal-only contract ("blocking on a
  judgment call is worse than the problem it solves") and the structural rule
  that keeps signal-only audits out of `audit-all`. Also forces a config
  resolver and a shell core into a purely declarative skill.

### B — A dedicated `refactor-extend` skill

- **Pros:** clean separation; no change to `audit-style`.
- **Cons:** splits one ruler across two skills that must agree on thresholds
  and vocabulary forever; the premature-abstraction and rigidity verdicts
  would drift apart, which is the exact incoherence this axis exists to fix.

### C — Static fan-out instead of historical co-change

- **Pros:** answers "what calls this?" directly.
- **Cons:** needs a per-language parser, reintroducing the `madge`/adapter
  dependency the constraint forbids. Fan-out also proves only that coupling
  *exists*; co-change proves it repeatedly **cost** something, which is the
  evidence that licenses maintainability over YAGNI.

### D — `architect` investigates git history itself, per PR

- **Pros:** no new tooling; the finding is born inside architectural judgment.
- **Cons:** non-deterministic (same diff, varying result), and it burns opus
  tokens on raw `git log` output for every non-trivial PR. Measurement is
  arithmetic; it does not need a model.

## Consequences

### Positive

- Zero LLM tokens to compute the evidence; only interpretation costs tokens.
- Works with no CI, no orphan ref, no stack adapter, in any language — the
  reader half of `code-metrics` already degrades gracefully without a baseline,
  and these signals need no baseline at all.
- The premature-abstraction verdict gets harder too: it moves from taste to the
  same measured ruler.
- `mentor` inherits the new finding type with no structural change (ADR-002).

### Negative

- `audit-style` gains a dependency on a CLI subcommand; it is no longer purely
  declarative, even though it still implements no calculation itself.
- A third layered-config reader (after `kr_*` and `cm_*`) is implied. That is
  the third occurrence, which licenses extracting a shared resolver — tracked
  as a separate follow-up, not in this scope.

### Risks

- **Noise.** A mature repo has many co-change clusters. The success criterion
  is that findings speak to *the change under review*, not to ambient debt;
  ranking and a per-PR ceiling are open spec questions.
- **Cargo-cult patterns.** Naming a GoF pattern invites the wrong one. The
  mitigation is the binding rule: a pattern is never named without the evidence
  that justifies it, and `architect` already requires an ADR for a new pattern.
- **Silent degradation.** A shallow clone truncates the churn window and would
  under-report without saying so. `hotspots` currently answers `0` when `lizard`
  or `git` is missing; for rigidity, `0` is a dangerous lie — it must report
  *unavailable* instead.
- **Model tier.** `audit-style` runs on Haiku. Interpreting clusters and naming
  principles may need to escalate, or leave naming to `architect` (opus).
