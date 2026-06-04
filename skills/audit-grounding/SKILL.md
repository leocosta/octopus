---
name: audit-grounding
description: >
  Signal-only review confronting the working diff against the repo's source of
  truth — CONTEXT.md (domain glossary), docs/adr/, and the knowledge base — to
  surface semantic hallucination: conventions invented without agreement
  (invented-convention) and domain facts asserted without support
  (unsupported-domain-fact). Never blocks. Triggered at task end by the
  grounding-check stop hook; quality bundle.
triggers:
  keywords: ["audit grounding", "grounding check", "invented convention", "hallucination check", "source of truth"]
---

# Source-of-Truth Grounding Audit

## Overview

A formatter, a type checker, and a secret scanner judge **syntax** —
they cannot tell whether a naming pattern was actually agreed by the
team, or whether a sentence in a comment states a true fact about the
domain. Those two failures are *semantic* hallucination, and the only
thing that can judge them is a reader holding the team's source of
truth in one hand and the diff in the other.

`audit-grounding` is that reader. It loads the living source of truth
the team already maintains and confronts the diff against it, emitting
two kinds of finding:

- **`invented-convention`** — a naming, folder, field, or structural
  pattern introduced by the diff that is **not** present in the source
  of truth and was never agreed.
- **`unsupported-domain-fact`** — a claim about the domain or business
  (in code, comments, or docs touched by the diff) that **contradicts**
  or is **absent from** the decisions of record.

The skill is **signal-only**: it never blocks a commit, a task, or a
merge. The verdict comes from a probabilistic reading of documents, so
blocking on it would be worse than the problem it solves. It reports;
the human decides.

## When to Engage

Engage when:

- A `Stop` hook fires it automatically at the end of an agent task
  (the default path — see `hooks/stop/grounding-check.sh`).
- A reviewer wants to check, before merge, whether an agent invented a
  convention or asserted an unsupported domain fact.

Do **not** engage for:

- Syntactic concerns — formatting, type errors, secrets. Those are the
  `guardrails` bundle's job (pre-commit + loop-level hooks) and they
  *block*; this skill does not duplicate them.
- Non-existent APIs or missing files that break the build — the
  compiler and type checker already catch those.

## The Source of Truth

Load, in order, and degrade gracefully when an artifact is absent:

1. **`CONTEXT.md`** — the domain glossary and the team's vocabulary.
   The primary reference for `invented-convention`.
2. **`docs/adr/*`** — decisions of record. The primary reference for
   `unsupported-domain-fact`.
3. **The knowledge base** (`knowledge/`) — accumulated facts and
   patterns the team has chosen to preserve.
4. **Module-scoped context** — any nested `CLAUDE.md` covering the
   directories the diff touches.

When `CONTEXT.md` is missing, fall back to `docs/adr/` and the
knowledge base; report the absence as an `info` note so the team knows
the grounding was partial.

## Protocol

1. **Scope the diff.** Use the same ref discovery the other `audit-*`
   skills use (working tree, a branch, or a PR ref). Restrict attention
   to changed lines and the files they touch.
2. **Load the source of truth** in the order above.
3. **Hunt invented conventions.** For each new convention the diff
   introduces — a field name, a folder layout, a status enum, a naming
   pattern — check whether it is grounded in `CONTEXT.md` or an ADR. If
   it is not, emit an `invented-convention` finding citing the diff
   location and noting which source it should have matched.
4. **Hunt unsupported domain facts.** For each domain or business claim
   the diff asserts, check it against the decisions of record. If it
   contradicts an ADR or is absent from all sources, emit an
   `unsupported-domain-fact` finding.
5. **Report.** Emit findings in the same severity-tiered shape as
   `audit-all`, but capped at `warn`/`info` — **never `block`**. State
   explicitly in the report header that the audit is signal-only.

## Report Shape

Mirror `audit-all`'s tiered report, with the blocking tier disabled:

- **`warn`** — a likely divergence the human should look at before
  merge (invented convention with no source match; a domain claim that
  contradicts an ADR).
- **`info`** — a weaker signal or a partial-grounding note (claim absent
  from the source but not contradicting it; `CONTEXT.md` missing).

Each finding names the diff location, the finding type
(`invented-convention` / `unsupported-domain-fact`), the source it was
checked against, and a one-line "what to confirm". The audit emits no
`block` tier by design.

## Anti-Patterns

- Blocking on a finding — forbidden; this skill is signal-only.
- Flagging syntactic issues the `guardrails` bundle already blocks.
- Inventing a divergence when the source of truth simply does not cover
  the area — say "not covered" (`info`), do not manufacture a `warn`.
- Editing the source of truth or the diff — the skill is read-only.

## Integration with Other Skills

- **`audit-config`** — sibling audit over the configuration surface;
  this one audits the diff against the domain source of truth.
- **`audit-all`** — code audits; `audit-grounding` complements it with
  the semantic-grounding dimension and shares its report shape.
- **`review-proposals`** — consumes the proposals the grounding-check
  stop hook routes to `.octopus/proposals/`.
- **`guardrails` bundle** — owns the syntactic, blocking layer this
  skill deliberately does not duplicate.
## Model tier

This audit is mechanical — it pattern-matches a diff against a fixed
checklist, not deep reasoning. Run it on the **cheapest model tier**
(`--model haiku` / each assistant's cheapest). Reserve frontier models
for the `architect`/`dba`/`security` roles that adjudicate the findings
(RM-130).
