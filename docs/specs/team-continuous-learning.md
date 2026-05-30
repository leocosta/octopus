# Spec: team-continuous-learning

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-30 |
| **Author** | Leonardo |
| **Status** | Approved (deep interview-refined 2026-05-30) |
| **RFC** | N/A |
| **Roadmap** | RM-093 (Cluster 16) — extends `continuous-learning`; ties to the fleet model (RM-094/095) |

## Problem Statement

The existing `continuous-learning` captures domain insight from a **single developer's session** into `knowledge/<domain>/`. It does not see that **the whole team keeps making the same mistake** across PRs and repos. So the manager re-types the same review comment in repo after repo, and that recurring correction never becomes a team rule. The team-level loop closes that gap: recurring PR-review feedback, aggregated across the fleet, becomes a rule-promotion candidate — and a fleet-wide pattern promotes to the **shared `workspace:` rules** every repo inherits.

## Goals

- A **team mode on `continuous-learning`** (not a separate skill) that aggregates **recurring review feedback** (`pr-review` / `architect` / `mentor` findings) across the fleet and surfaces repeated patterns as **rule-promotion candidates**.
- Capture is **continuous and automatic** via a Stop hook that logs review findings to `.octopus/review-log/`; aggregation is **operator-run** (like `audit-fleet`).
- **Fleet-aware routing:** a pattern spanning multiple repos promotes to the `workspace:` shared rules; a single-repo pattern stays local. Thresholds are configurable in `fleet.yml` with defaults.
- Feeds the existing promotion path (`.octopus/proposals/` → `/octopus:review-proposals` → `rules/` / `knowledge/`). **Human-gated; never auto-edits rules.**
- Registered in the `tech-lead` bundle (RM-096); interim `docs`.

## Non-Goals

- Not a separate skill — it is a **mode** of `continuous-learning` (one mental model).
- Not auto-promotion — candidates require human review (the proposals-queue discipline).
- Not management analytics — it produces rule candidates, not people/velocity metrics.
- Not per-session single-dev capture (that's the existing default mode).
- Not a new store — reuses `.octopus/proposals/` + `/octopus:review-proposals`.

## Design

### Overview

Two halves, mirroring the existing capture→promote loop at fleet scale:

1. **Capture (continuous, automatic).** A Stop hook reads the session transcript, detects review findings (the `BLOCKING:`/`ADVISORY:`/`QUESTION:` tags the review roles emit, and `pr-review`/`mentor` report blocks), and appends a structured entry to `.octopus/review-log/` — no edits to the review skills.
2. **Aggregate + promote (operator-run).** The `continuous-learning` **team mode** mines the review-log across the fleet, groups findings by normalized topic, counts occurrences and **repo spread**, and writes rule-promotion candidates to `.octopus/proposals/` for `/octopus:review-proposals`.

### Detailed Design

**Capture — the Stop hook (`hooks/stop/review-log-capture.sh`):**
- Reads `transcript_path` from stdin (same contract as `propose-knowledge-update`); soft-skips without `jq`/transcript.
- Extracts review findings from the transcript: lines tagged `BLOCKING:`/`ADVISORY:`/`QUESTION:`, and findings rows from a `Code Review Report` / `pr-review` block.
- Appends one structured entry per finding to `.octopus/review-log/<YYYY-MM-DD>.md`: `date · repo · source (architect/security/mentor/pr-review) · severity · finding text (normalized topic hint)`.
- Read-only on the project tree; writes only under `.octopus/review-log/` (gitignored).

**Review-log entry (appended):**
```
- 2026-05-30 | repo=billing-api | src=architect | sev=ADVISORY | topic="missing test for error path" | file=users/service.ts:42
```

**Aggregate — `continuous-learning` team mode:**
- **Fleet resolution:** reuse the `fleet.yml` `repos:` list (RM-094/095). Mine each repo's `.octopus/review-log/` (+ bootstrap from existing artifacts: `pr-review` PR comments, `mentor` `docs/mentoring/`, `.octopus/proposals/`).
- **Normalize + group** findings by topic (e.g. "missing test for error path", "custom exception without catch site").
- **Count** occurrences and **distinct-repo spread** per topic within a window.
- **Threshold (configurable, with defaults):**
  ```yaml
  # fleet.yml
  learning:
    local: 5         # 5+ occurrences within a single repo → local candidate
    fleet_repos: 3   # appears in 3+ distinct repos → workspace candidate
  ```
  Spread routes the destination (per the merge model): multi-repo → `workspace:` shared rules; single-repo → that repo's local rules.

**Candidate shape (`.octopus/proposals/<ts>-team-pattern.md`):**
- **Pattern:** the recurring finding, normalized.
- **Frequency:** N occurrences across which PRs/repos (cited) + distinct-repo count.
- **Proposed rule:** a draft line for `rules/common/<topic>.local.md` (workspace or local) or a `knowledge/` entry.
- **Route + destination:** `workspace` (≥ `fleet_repos`) or `local` (≥ `local`), promoted via `/octopus:review-proposals`.

**Promotion:** reuses `/octopus:review-proposals` — the manager promotes/partials/archives. No auto-edit; a workspace-routed candidate, when promoted, writes to the workspace repo's shared `rules/common/*.local.md` (inherited fleet-wide).

**Cadence:** capture is continuous (the hook fires every session with review output); aggregation is operator-run v1 (the manager runs team mode, pairing with the weekly `review-proposals` habit). Consistent with `audit-fleet`/`fleet-bootstrap` being operator-run.

### Migration / Backward Compatibility

Additive. The default (single-dev) `continuous-learning` is unchanged. The hook writes only to gitignored `.octopus/review-log/`. Without a `fleet.yml`, team mode degrades to single-repo aggregation with the default `local` threshold. Produces nothing until there is review data.

## Implementation Plan

1. `skills/continuous-learning/SKILL.md` — add a **`## Team mode`** section: the review-log source, fleet resolution, normalization + spread thresholds (`fleet.yml learning:`), candidate shape, fleet-wide→workspace vs single-repo→local routing, promotion via `/octopus:review-proposals`, and the no-auto-promote discipline. Update frontmatter to mention the team/review scope.
2. `hooks/stop/review-log-capture.sh` — the capture hook (transcript → `.octopus/review-log/`), mirroring `propose-knowledge-update`'s structure; register in `hooks/hooks.json` (Stop) and add `.octopus/review-log/` to `.gitignore`.
3. Document the `fleet.yml` `learning:` block (in the `fleet-bootstrap` / `audit-fleet` fleet.yml example).
4. Register team-mode capability in `bundles/docs.yml` (interim, where `continuous-learning` already lives); `tech-lead` (RM-096) final.
5. `tests/test_team_continuous_learning.sh` — grep-structural: team mode declared; review-log capture hook exists + registered; fleet-wide aggregation + spread; configurable thresholds w/ defaults; fleet-wide→workspace routing; writes to `.octopus/proposals/`; promotes via `review-proposals`; no auto-promote.
6. Docs site: `docs/site/skills/team-continuous-learning.mdx` (or extend the `continuous-learning` page with the team mode) + pt-br pair; index rows. Optionally a hooks page for the capture hook.

## Context for Agents

**Knowledge modules**: [documentation]
**Implementing roles**: [tech-writer, backend-developer]
**Related ADRs**: N/A (reuses existing loop + the fleet model)
**Skills needed**: [scaffold-skill, continuous-learning, audit-fleet]
**Bundle**: `docs (existing)` interim; `tech-lead (proposed, RM-096)` final
**Constraints**:
- Team **mode** on `continuous-learning`, not a new skill.
- Capture via a Stop hook (no edits to the review skills); aggregation operator-run.
- Fleet-aware: reuses `fleet.yml`; multi-repo patterns route to the `workspace:` rules.
- Reuses `.octopus/proposals/` + `/octopus:review-proposals`; human-gated, never auto-edits.
- Markdown skill + bash hook + grep-based test; pt-br site pair with source_hash.

## Testing Strategy

- Structural grep test (above).
- Scenario checks: (1) a review-log fixture with one topic in 3 repos → a workspace-routed candidate; (2) a topic 5× in one repo → a local candidate; (3) a topic seen once → nothing; (4) the capture hook, given a transcript with `BLOCKING:`/`ADVISORY:` lines, appends entries; given none, writes nothing.

## Risks

- **Noise / false patterns:** mitigated by the thresholds (occurrence + repo spread) and the human gate.
- **Topic normalization is fuzzy:** the spread/threshold and human review absorb imperfect grouping; the hint is a topic *candidate*, confirmed at promotion.
- **Capture depends on review output in the transcript:** true; `architect`/`security`/`mentor`/`pr-review` already emit tagged findings, so the hook has a stable pattern to match; mining existing artifacts backstops gaps.
- **Workspace write on promotion:** human-gated via `review-proposals`; the candidate proposes, the manager promotes.

## Changelog

- **2026-05-30** — Initial draft.
- **2026-05-30** — Deep interview refinement: team **mode** on `continuous-learning` (not a new skill); `.octopus/review-log/` backbone captured by a Stop hook (no edits to review skills) + mining existing artifacts as bootstrap; fleet-wide aggregation reusing `fleet.yml`; spread-based routing (multi-repo → `workspace:` rules, single-repo → local) with configurable `fleet.yml learning:` thresholds and defaults; operator-run aggregation.
