# Spec: Review Reflection Pass

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-08-04 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-171 (Cluster 31 — review-engine parity) |

## Problem Statement

`codereview` blocks a commit on any open BLOCKING finding, and nothing stands
between a finding and that block. A false BLOCKING therefore stops real work —
and the fastest way to teach a team to bypass the gate is to block them wrongly
once. Precision is a precondition for having an automated gate at all, not a
refinement of one.

The same cost shows up without the gate: twelve findings where four are noise
cost more to triage than four findings, because every one must be read and
dismissed by a human who cannot tell them apart in advance. This is where review
gets abandoned.

Octopus has `audit-grounding` and `audit-verification`, but both are signal-only
and run after the fact. Neither stands between a finding and the report.

## Goals

- Every finding that came from a model is re-read against its own anchored code
  before the report is printed or posted, with the burden of proof on the finding.
- A rejected finding that could block is **demoted, not deleted** — the gate stops
  firing, the claim stays readable.
- A rejected finding that could not block is dropped, and the discard reason is
  persisted, so an over-aggressive filter is visible rather than a silent hole.
- The filter cannot lose a finding by failing: every failure path leaves the
  report unchanged.
- Selection, code extraction and verdict application are code, not prose. The
  model does only the judgement.

## Non-Goals

- **Not finding new issues.** The adjudicator answers one question per finding —
  does the code shown sustain this claim — and never reports anything not already
  in the report.
- **Not judging locations.** That is RM-170, and it runs first; this pass consumes
  its verdicts.
- **Not measuring precision.** Whether the filter is calibrated is unprovable
  until RM-175 exists. This spec ships the mechanism and the audit trail that
  RM-175 will score.
- **Not a new skill.** Like RM-170, this is a command plus a phase in the two
  orchestrators — no bundle entry.

## Design

### Overview

- `cli/lib/reflect-payload.sh` — sourceable library, no side effects: eligibility,
  code-window extraction, payload emission, verdict application.
- `cli/lib/review-reflect.sh` — the `octopus review-reflect prepare|apply` command.

Same split as RM-170/RM-172: helper libs stay out of `cli/lib/commands.default`,
so they are never dispatchable.

Flow, as a new Phase 4.55 between anchor verification and the record:

```
Phase 4.5   anchor        → report.txt (unanchored findings already demoted)
Phase 4.55  prepare       → payload.txt        exit 1 = nothing eligible, skip the model
            sub-agent     → verdicts.tsv       one sonnet call, batched
            apply         → report.txt' + filtered.tsv
Phase 4.6   record --filtered filtered.tsv
Phase 5     the block is decided over the filtered report
```

### Detailed Design

**Eligibility** is resolved in bash, not by the model. A finding enters the
payload iff both hold:

1. Its `[origin: …]` is a role (`architect`, `dba`, `security`) or an `audit-*`
   skill. `fallback` (Phase 3) and `definition-of-done` (Phase 3.5) are excluded —
   those are deterministic greps and per-item verdicts, true by construction, and
   paying a model to adjudicate a `TODO` match is waste.
2. Its RM-170 anchor verdict is `anchored` or `not-in-diff`. `no-anchor` is
   excluded: there is no code to confront, and judging prose against prose is what
   this pass exists to avoid. `line-out-of-range` and `missing-file` were already
   demoted by Phase 4.5 and no longer block anything.

This is why RM-171 depends on RM-170: eligibility is defined in terms of anchor
verdicts.

**Code window.** For each eligible finding, `git show <ref>:<path>` sliced to
±15 lines around the cited line, line-numbered, with the cited line marked.
Truncates cleanly at both ends of the file. Reuses the RM-170 resolution — no
second `git diff`. This is what bounds the cost: the adjudicator sees N windows,
never the whole diff.

**Payload format.** Plain delimited text, not JSON — the consumer is a model, and
a text block is cheaper per finding and easier to assert in tests. A header line
carries the tier:

```
OCTOPUS_REFLECT_MODEL sonnet

--- FINDING 1 ---
severity: BLOCKING
anchor: anchored
text: [origin: dba] Missing index on orders.tenant_id — db/schema.sql:42
code: db/schema.sql (cited line 42, marked >)
       27 | ...
>      42 | ...
       57 | ...
```

`origin` is not a field of its own: it travels inside `text`, which is the
finding's report line verbatim, `[origin: …]` tag included. `anchor` is the
RM-170 verdict, and it is the one thing the window cannot show — `not-in-diff`
says the cited line is pre-existing and this change never touched it, which is
frequently the whole answer to "does this code sustain the claim".

Finding ids are the eligible findings' ordinal position, in report order,
starting at 1. `apply` re-derives eligibility from the same report, which is why
it also takes `--base` and `--ref` — eligibility is defined in terms of anchor
verdicts, and those need the diff. No state travels between the two calls.

Emitting the tier from `prepare` keeps the RM-130 policy verifiable. Every other
tier declaration lives in frontmatter (`SKILL.md`, `roles/*.md`) and is asserted
by `tests/test_model_tiering.sh`; this pass has neither a skill nor a role, so the
tier is data the command reads rather than an instruction the model may ignore.

**Adjudication contract.** The burden of proof is on the finding: it survives only
if the shown window sustains it. "Something elsewhere might justify it" is
`reject`. One explicit exception, because it is the dominant false-reject mode —
if the window does not show enough to judge (a claim about coupling across files,
for instance), the verdict is `keep`. Doubt favours the finding.

**Verdicts** are a TSV, `<id><TAB>keep|reject<TAB><one-line reason>`. `apply` is
deterministic:

| Verdict | Severity | Effect |
|---|---|---|
| `keep` | any | line untouched |
| `reject` | BLOCKING / CRITICAL | moved to ADVISORY, prefixed `(was BLOCKING; reflection: …)` |
| `reject` | HIGH / ADVISORY / MEDIUM / LOW / QUESTION | removed from the report, written to `filtered.tsv` |

`filtered.tsv` is
`<severity><TAB><origin><TAB><path><TAB><line><TAB><reason>`, one dropped finding
per line. It is tab-delimited for the same reason `review_record_parse`'s rows
are — `awk -F'\t'` reads it without collapsing an empty column — but it is not
the same shape: five columns against that function's seven, because a dropped
finding has no anchor verdict left to record and no report line to quote. It
gets its own `awk` reader in `review_record_json`, next to the findings one.

The asymmetry is deliberate. The risks are not symmetric: wrongly dropping a
claim that called itself critical is the one failure this pass could introduce,
while wrongly keeping a MEDIUM costs one line of reading. Demotion buys the gate
back without letting the filter delete a serious claim.

**Fail-open, at three points.** The filter must never lose a finding through a
defect of its own:

1. `prepare` with nothing eligible exits 1 and the orchestrator skips the model
   call entirely — the same "don't spawn" saving as `audit-scope` (RM-172).
   Exit codes follow `review-anchor`: 0 a payload was produced, 1 nothing was
   eligible, 2 usage or repository error. Only 2 is an error worth reporting.
2. A failed sub-agent, or a missing/empty verdicts file, leaves `apply` returning
   the report byte-identical.
3. An id the adjudicator did not mention is treated as `keep`. Only an explicit
   `reject` removes anything.

**Summary line.** `apply` writes
`OCTOPUS_REFLECT_SUMMARY kept=N demoted=N filtered=N` to **stderr**, so an
over-aggressive filter is visible in the run's own output and not only in the
record. stdout is the rewritten report body and nothing else: the documented
`apply … > <report>.new && mv <report>.new <report>` pipeline captures stdout
verbatim, and a summary line mixed into it would be persisted into the report
and, through `pr-review`'s `--body-file`, posted into a public PR comment. The
orchestrators are told to report the line anyway.

**Record integration (RM-176).** `review-session record` gains `--filtered <file>`:

- `findings[]` gains an optional `reflection` field, present only on demoted
  findings, carrying the reason. It is recovered from the finding's own text —
  `apply` writes the reason into the line as `(was <SEVERITY>; reflection: …)`,
  and the record parser reads it back from there. Nothing is threaded between the
  two commands; the report stays the single source of truth.
- A new `filtered[]` array holds the dropped ones: original severity, origin,
  path, line, reason.
- `review-session show` gains `--filtered`.

Additive on purpose: an existing consumer reading `findings[]` still reads "what
was reported". `review_record_parse` keeps its shape, with `reflection` as an
extra trailing column — the `awk -F'\t'` read path documented in
`cli/lib/review-record.sh` handles the empty-field case that `IFS=$'\t' read`
would collapse.

### Migration / Backward Compatibility

Additive. A review that never calls `review-reflect` behaves exactly as before,
and `--filtered` is optional, so the command can ship ahead of either orchestrator
adopting it. Records written without it are valid — `filtered[]` is simply empty.

## Implementation Plan

1. `cli/lib/reflect-payload.sh` — eligibility, code windows, payload emission,
   verdict application.
2. `cli/lib/review-reflect.sh` + `commands.default` registry entry.
3. `tests/test_review_reflect.sh` — git fixtures.
4. `review-record.sh` / `review-session.sh` — `--filtered`, the `reflection`
   field, `show --filtered`, and their tests.
5. `commands/codereview.md` Phase 4.55 and the Phase 5 non-blocking rule extended
   to reflection-demoted findings; `commands/pr-review.md` Phase 4.55 before
   posting.

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [architect]
**Related ADRs**: N/A
**Skills needed**: [implement, test-tdd]
**Bundle**: N/A — no new skill.

**Constraints**:
- Pure bash on both bookends; `git` and POSIX text tools only.
- Exactly one model call per review, batched over all eligible findings.
- Every failure path leaves the report unchanged.
- Follow the `cli/lib/audit-scope.sh` conventions (documented API header, helper
  libs stay out of the registry, `set +e` note for sourcing under `-e`).

## Testing Strategy

`tests/test_review_reflect.sh`, against throwaway git repositories:

- **Eligibility**: `fallback` and `definition-of-done` origins excluded; `no-anchor`
  excluded; role and `audit-*` origins with `anchored`/`not-in-diff` included.
- **Code window**: correct slice mid-file; truncation at both file boundaries; the
  cited line is marked.
- **`prepare`**: exit 1 and no payload when nothing is eligible;
  `OCTOPUS_REFLECT_MODEL sonnet` in the header; every finding carries its
  `anchor:` verdict, and the verdict follows the diff.
- **Usage errors**: a report that exists but cannot be read is exit 2, not the
  exit 1 that means "nothing was eligible"; a flag given no value is exit 2, not
  a hang.
- **The reason is free text**: `&`, `\`, parens, tabs and CRs all round-trip or
  are stripped, and a `path:line` inside a reason never displaces the demoted
  finding's own citation — in the record, or on a second `apply`.
- **`apply`**: a rejected BLOCKING is demoted and still present; a rejected MEDIUM
  is removed and appears in `filtered.tsv`; `keep` leaves the line untouched; an
  unmentioned id is kept; an empty verdicts file yields a byte-identical report.
- **Summary**: `OCTOPUS_REFLECT_SUMMARY` counters match the applied verdicts.
- **Record**: `filtered[]` and `reflection` present in the JSON;
  `show --filtered` returns them; a record written without `--filtered` stays valid.
- **Registry**: `review-reflect` in `commands.default`, `reflect-payload.sh` out.

## Risks

- **Over-aggressive filtering** is the real risk, and it is unprovable before
  RM-175 — the roadmap says as much. Mitigated within this scope by the
  asymmetric verdict (a blocker never disappears), the auditable `filtered[]`, and
  the summary counters in the run's own output.
- **Windows too narrow.** A claim about coupling across two files does not fit in
  ±15 lines and would tend to a wrong `reject`. Mitigated by the explicit
  contract rule: an insufficient window is `keep`.
- **Overlapping windows.** Two findings on the same region pay for that code
  twice. Accepted — deduplication complicates the id→finding mapping for a small
  gain at review scale.
- **Cost scales with finding count**, not diff size. A review that produced fifty
  findings pays fifty windows. Bounded in practice by the fact that such a review
  has a bigger problem than its token bill.

## Changelog

- **2026-08-04** — Initial draft (RM-171)
- **2026-08-05** — Reconciled with what shipped: the payload block (no `origin:`
  field, `anchor:` kept and now emitted), `filtered.tsv`'s real shape, and the
  summary line's stream (RM-171)
