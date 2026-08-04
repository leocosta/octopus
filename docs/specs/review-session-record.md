# Spec: Review Session Record

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-08-04 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-176 (Cluster 31 — review-engine parity) |

## Problem Statement

A review report is prose. `hooks/stop/review-log-capture.sh` (RM-093) recovers
part of it afterwards by grepping the session transcript for severity tokens — a
mechanism built for team learning, not for recording a review.

As a record it fails in five ways: it depends on the finding's text formatting;
it truncates at 40 silently; it disappears with the transcript; it keeps no
origin, `ref`, anchor or verdict; and it records nothing about which audits ran.
The last one matters most — without it, "no findings" and "nothing looked" are
indistinguishable.

There is also a concrete gap already visible in the repo:
`skills/continuous-learning/SKILL.md:126` documents the log line as

```
- 2026-05-30 | repo=billing-api | src=architect | sev=ADVISORY | topic="…" | file=users/service.ts:42
```

but the hook emits only `repo=`, `sev=` and `topic=`. `src=` and `file=` are
absent because a transcript grep cannot reliably supply them. The documented
format has been unachievable since it was written.

## Goals

- Every review run persists a structured record at the moment it runs, carrying
  per-finding origin, severity, anchor verdict (RM-170) and location, plus the
  per-audit `skip`/`cached`/`scoped` resolution (RM-172) and the reviewed sha.
- Review output is queryable: `--json` and `--severity` filtering.
- `review-log-capture` consumes the record when present, which removes the
  40-finding cap and the format coupling from RM-093 and closes the `src=`/`file=`
  gap above.
- Nothing regresses when no record exists — the transcript path stays as fallback.

## Non-Goals

- **`--resume` for an interrupted fan-out.** It needs incremental writes during
  Phase 2, which changes the dispatch contract. The record is the precondition;
  resuming is separate work.
- **The browser replay viewer** OCR ships. The value is the record and the flag.
- **Changing the review-log line format.** `continuous-learning` reads it; this
  fills fields it already documents rather than inventing new ones.

## Design

### Overview

- `cli/lib/review-record.sh` — sourceable: parses an aggregated report into rows,
  renders the JSON record.
- `cli/lib/review-session.sh` — the `octopus review-session` command
  (`record` / `list` / `show`).

Same split as RM-170 and RM-172: helper libs stay out of `commands.default`.

### Detailed Design

**Parsing.** A section header (`BLOCKING (2)`) sets the severity in force; a line
carrying `[origin: x]` is a finding. Both severity scales are accepted —
`codereview` Phase 4 merges the roles' BLOCKING/ADVISORY/QUESTION with the audit
skills' CRITICAL/HIGH/MEDIUM/LOW without flattening them. Locations are resolved
through RM-170, so a record cannot claim a position the diff does not support.

**Record shape** — `.octopus/reviews/<UTC-stamp>-<short-sha>[-n].json`:

```json
{
  "created_at": "…", "repo": "…", "base": "main", "ref": "HEAD", "ref_sha": "…",
  "audits":   [{"name": "audit-money", "outcome": "scoped"}],
  "findings": [{"severity": "BLOCKING", "origin": "dba", "path": "src/a.ts",
                "line": 12, "anchor": "anchored", "text": "…"}]
}
```

The `-n` suffix disambiguates two reviews of the same sha in the same second —
which is exactly the fix-and-re-run loop, not a corner case.

**Writing is jq-free** (hand-rolled escaping) so a record is still produced in
degraded environments; `jq` is required only for `--severity` filtering and
`list --json`.

**Hook integration.** `review-log-capture.sh` consumes unconsumed records first,
tracked by a watermark at `.octopus/review-log/.last-record`, and only falls back
to the transcript grep when there are none. Record ids sort chronologically by
construction, so the watermark is a lexical compare.

### Migration / Backward Compatibility

Additive. A review that never calls `record` behaves as today, and the hook's
transcript path is untouched for those runs. The review-log line format is
unchanged — previously-empty fields are now populated.

## Implementation Plan

1. `cli/lib/review-record.sh` — parse + JSON render.
2. `cli/lib/review-session.sh` + registry entry.
3. `tests/test_review_session.sh`.
4. `commands/{codereview,pr-review}.md` — Phase 4.6.
5. `hooks/stop/review-log-capture.sh` — consume records, keep the fallback.

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [architect]
**Related ADRs**: N/A
**Skills needed**: [implement, test-tdd]
**Bundle**: N/A — no new skill.

**Constraints**:
- Pure bash; `jq` required only on the query path, never to write a record.
- Never mutate the report.
- Deterministic: no model call anywhere in this path.
- The review-log line format is a published contract — fill fields, do not rename.

## Testing Strategy

`tests/test_review_session.sh` (37 assertions) against throwaway git repos:
parsing of all severities and origins; `no-anchor`, `not-in-diff` and
`missing-file` findings; report chrome ignored; valid JSON including embedded
quotes and backslashes; audit resolutions preserved; `ref_sha` pinned; same-second
id collision; gitignore guard idempotence; `list`/`show`, `latest`, `--severity`
case-insensitive and multi-valued; hook emitting `src=`/`file=`, not re-appending
consumed records, and writing a watermark.

## Risks

- **Report format drift.** Parsing depends on `[origin: x]` and the section
  headers from `codereview` Phase 4. A format change silently yields an empty
  record. Mitigated by the finding count printed on `record`, which makes zero
  visible — but a stronger guard would be a test asserting the command's own
  documented example parses.
- **Unbounded growth.** `.octopus/reviews/` accumulates one file per run with no
  pruning. Gitignored and small (KBs), but it should get a retention policy
  before this ships to a fleet.
- **Watermark and clock.** Ids are UTC-stamped, so a machine with a badly skewed
  clock could write an id that sorts before the watermark and never gets consumed.
  Acceptable; worth noting.

## Changelog

- **2026-08-04** — Initial draft (RM-176)
