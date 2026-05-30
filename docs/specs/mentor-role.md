# Spec: mentor-role

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-30 |
| **Author** | Leonardo |
| **Status** | Approved (refined via interview 2026-05-30) |
| **RFC** | N/A |
| **Roadmap** | RM-089 (Cluster 16) |

## Problem Statement

The gate roles (`architect`, `dba`, `security`) *judge* a diff (BLOCKING / ADVISORY / QUESTION) but do not *teach the why*. An engineer corrected ten times for the same reason stays dependent on the corrector. To raise team autonomy — the manager's stated nº1 goal — review has to transfer reasoning, not just verdicts. There is no role today whose job is pedagogy.

## Goals

- A `mentor` review role that, for the **findings already produced** by the gate roles, **explains the reasoning** behind each one: the principle at stake, the trade-off, the better path, and *why* it's better.
- Cites the team's own sources (`rules/`, `docs/adr/`, `CONTEXT.md`) so the lesson is grounded, not opinion.
- Pairs with the gate roles: they gate (can this merge?), mentor teaches (what should you learn from this?). The concerns stay separate.
- Usable on-demand via `/octopus:delegate @mentor`; registered in the `tech-lead` bundle (RM-096).

## Non-Goals

- Not a gate. Mentor never blocks a merge — it produces teaching, not approval. (Blocking stays with `architect`/`security`/`dba`.)
- Not a rewrite bot. It explains and points; it does not silently apply fixes.
- Not a re-reviewer. It does not re-analyze the diff or re-run the gate roles — it consumes the findings they already produced.
- Not automatically dispatched. It runs only when explicitly invoked (no codereview/pr-review matrix wiring, no per-engineer flag).

## Design

### Overview

A new role persona (`roles/mentor.md`) built on `roles/_base.md`, with output optimized for **learning transfer** instead of gate classification. Where the gate roles emit `BLOCKING/ADVISORY/QUESTION`, mentor emits **teaching units**: each finding becomes *what I see → principle → why it matters → better approach → source to read*, tagged with the origin role.

### Detailed Design

**Trigger — on-demand only.** Invoked via `/octopus:delegate @mentor` against a diff or PR. There is **no** automatic dispatch in `codereview`/`pr-review` and **no** per-engineer opt-in flag. The common form is a single dispatch (`/octopus:delegate @mentor: ensina o PR 142`); mentor fetches the findings itself.

**Input — already-produced findings**, obtained in priority order:
1. **Open PR** — the latest `/octopus:pr-review` report comment, pulled via `gh pr view <pr#> --comments` (the aggregated report `pr-review` Phase 5 posts). Primary path.
2. **Current session** — the `/octopus:codereview` report for the working tree, if one was just produced.
3. **Delegate pipeline** — `@architect (+ @dba + @security) → @mentor`, where the prior roles' outputs arrive via `pipelineContext`. Optional fresh-run path.

Each finding is parsed into: **origin role** (`architect`/`dba`/`security`), `file:line`, severity, and the reviewer's note. Mentor never re-runs the roles; if no findings exist it says so and points at `pr-review`/`codereview` rather than inventing any.

**Output — a teaching unit per finding**, origin-tagged:
- **What I see:** the specific code, cited by `file:line`.
- **Principle:** the rule/value at stake.
- **Why it matters:** the concrete cost of the current form (maintainability, the 2 AM incident, the next reader).
- **Better approach:** what to do instead, concretely.
- **Read more:** the team source that documents it (`rules/common/*`, an ADR, `CONTEXT.md`). If none exists, say so inline — that absence is a standards-gap signal.

**Read-only by default; persistence/PR posting flag-gated:**
- **default** → teaching units inline only. No file writes, no PR posting.
- **`--save`** → also write the lesson log to `docs/mentoring/<date>-<branch>.md`, and write a standards-gap stub to `.octopus/proposals/<ts>-mentor-standard-gap.md` for each undocumented-principle finding (for `/octopus:review-proposals`; ties to RM-092/`doc-adr` and the RM-093 loop).
- **`--pr`** → post each teaching unit as an inline PR comment (file:line), reusing the `gh pr comment` primitive (`pr-review` Phase 5).
- Flags compose (`@mentor --save --pr: …`).

**Tone contract (in the persona):** explain to a capable peer, never condescend; one teaching unit per real finding, not a lecture on everything; prefer the team's documented reasoning over generic best-practice when both exist.

**Design decision — separate role vs. "teach mode" on architect:** chosen *separate role*. Gating and teaching are different jobs with different output shapes and failure modes (a gate that hedges is useless; a lesson that just says "blocked" teaches nothing). Keeping them separate lets a PR be gated by the gate roles **and** taught by `mentor` without one diluting the other. Recorded as an ADR (see Risks).

### Migration / Backward Compatibility

Additive. No change to the gate roles or existing dispatch. Repos that don't adopt `mentor` see nothing. By default mentor makes no writes, so it adds no artifacts unless `--save`/`--pr` are used.

## Implementation Plan

1. `roles/mentor.md` — persona on `_base.md`: mission (teach the why), the obtain-findings protocol (pr-review/codereview report or pipeline context), the origin-tagged teaching-unit shape, source-citation + inline gap note, `--save`/`--pr` flag handling, the tone contract, and the non-gate + default-read-only boundaries.
2. `skills/delegate/SKILL.md` §C — add alias rows `mentor`/`coach`/`teacher` → `mentor` so resolution + pre-flight validation pass.
3. Role install/generation — `mentor` is emitted to `.claude/agents/` / `.opencode/agents/` via the existing `deliver_roles` path once it's in a delivered bundle/`.octopus.yml`.
4. `tests/test_mentor_role.sh` — grep-structural (role exists, teaches architect/dba/security findings origin-tagged, teaching-unit shape, non-gate boundary, source citation, default inline-only/read-only, `--save`/`--pr` behavior, reads already-produced findings, delegate alias present).
5. Register `mentor` in `bundles/tech-lead.yml` (RM-096). Until that bundle ships, add it directly to a repo's `.octopus.yml` roles.
6. **ADR**: record "mentor as separate role vs. architect teach-mode" (see Risks — passes the triple gate).
7. Docs site: `docs/site/roles/mentor.mdx` + pt-br pair; roles index rows (EN + pt-br).

## Context for Agents

**Knowledge modules**: [documentation]
**Implementing roles**: [tech-writer]
**Related ADRs**: [proposed: mentor-vs-architect-teach-mode]
**Skills needed**: [scaffold-skill, doc-adr]
**Bundle**: `tech-lead (proposed, RM-096)`
**Constraints**:
- Markdown role on `_base.md`; never emits a blocking verdict.
- Consumes already-produced gate-role findings; never re-runs the review.
- Read-only by default; only `--save` / `--pr` write (bounded to `docs/mentoring/**`, `.octopus/proposals/**`, PR comments).
- Every teaching unit cites a team source or flags its absence.
- pt-br site pair with source_hash, per site convention.

## Testing Strategy

- Structural grep test (above).
- Scenario checks: (1) reading a `pr-review` report yields origin-tagged teaching units citing sources, no writes; (2) `--save` writes the lesson log and a gap stub for an undocumented principle; (3) `--pr` posts inline PR comments; (4) a diff tripping both a `dba` and a `security` finding produces one `[dba]` and one `[security]` unit.

## Risks

- **Overlap/confusion with the gate roles:** mitigated by the explicit non-gate boundary and an ADR documenting the split. (Hard to reverse once the delegate alias + bundle depend on the split; a real alternative — architect teach-mode — existed.)
- **Noise (lecturing):** mitigated by "one unit per real finding" and by consuming only what a gate role already surfaced.
- **Teaching ungrounded opinion:** mitigated by mandatory source citation; absence of a source becomes a signal, not a fabricated lesson.
- **Stale/duplicated findings:** mitigated by reading the already-produced report rather than re-running the roles (no divergence from the verdict the engineer received).

## Changelog

- **2026-05-30** — Initial draft.
- **2026-05-30** — Refined via interview: on-demand only; consumes already-produced findings from architect/dba/security (no re-run); read-only by default with `--save`/`--pr` flags; lesson log + gap-proposal under `--save`; PR comments under `--pr`.
