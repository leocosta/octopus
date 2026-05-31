# Spec: Audit Verification

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo |
| **Status** | Draft |
| **Roadmap** | RM-111 (Cluster 20) |
| **RFC** | N/A |

## Problem Statement

RM-111. RM-088 shipped two sides of the local-guardrail triad — the **syntactic block** (`guardrails` bundle: formatter/typecheck/secret at commit) and the **semantic signal** (`audit-grounding` skill + `grounding-check` Stop hook: invented conventions, unsupported domain facts). Its [PRD](local-guardrails-quality-style-grounding.md) explicitly **deferred** the third side: the **verification** failure modes. An agent can declare a task complete or "tests passing" without ever running the build/test/typecheck, and can reference a symbol, import, or file that does not exist — the type-checker would catch the latter, but only if it is actually run. Today nothing surfaces either: the syntactic gate fires only at commit (an agent may stop without committing), and `audit-grounding` judges *meaning*, not *whether the work was verified*.

`audit-verification` is the verification signal — same shape as `audit-grounding` (a deterministic Stop hook + a signal-only LLM skill). At task end on a code diff, it confronts the session's completion claim against the run evidence and flags references the build would reject. It never blocks; it reports, the human decides.

Seed: the RM-088 PRD's Out-of-Scope section.

## Goals

- A `verification-check` **Stop hook** that, at task end on a code diff, queues a verification review (writes a proposal to `.octopus/proposals/`, like `grounding-check`). Deterministic trigger, signal-only, never blocks.
- An `audit-verification` **skill** that emits two finding kinds:
  - **`unverified-completion-claim`** — the session asserts done / passing / fixed, but no build/test/typecheck ran this session to support it.
  - **`unresolved-reference`** — the diff references a symbol / import / file that does not resolve (what the type-checker would reject — surfaced without needing the agent to have run it).
- Reuse the RM-088 plumbing: `.octopus/proposals/` queue, `/octopus:review-proposals`, the signal-only contract, the `guardrails`/`audit-grounding` pairing.
- Register in the `quality` bundle beside `audit-grounding`; no loose skill.
- **Cost discipline:** the recurring per-task component (the Stop hook) **never invokes an LLM**; `unresolved-reference` (missing-file) is detected deterministically in the hook; the LLM judgment (`unverified-completion-claim`) runs only on demand via `/octopus:review-proposals`, on the cheapest model tier.

## Non-Goals

- Blocking — verification is signal-only, like grounding; the syntactic gate already blocks at commit.
- Replacing the `guardrails` syntactic hooks or `audit-grounding`'s semantic judgment — this is the third, distinct side.
- Running the project's full test suite itself — it confronts what *did* run against the claim; it is not a test runner.
- The semantic failure modes (invented convention, unsupported fact) — those are `audit-grounding`.

## Design

### Overview

A deterministic `verification-check` Stop hook (**pure bash, zero LLM**) fires at task end. On a code diff it scans the session transcript for run evidence (did a build/test/typecheck execute?) and checks the diff for added file references that don't resolve on disk; it queues a proposal to `.octopus/proposals/` **only when something looks unverified**. The `audit-verification` skill — invoked **on demand** via `/octopus:review-proposals`, on the cheapest model tier — judges the `unverified-completion-claim` from the diff + transcript. Mirrors `grounding-check` + `audit-grounding`; signal-only. **The recurring per-task piece never invokes an LLM** — cost is deferred, batched, and human-triggered.

### Detailed Design

**`verification-check` Stop hook (bash, zero LLM).** Mirrors `hooks/stop/grounding-check.sh` and `review-log-capture.sh`:

- Reads the Stop JSON on stdin → `transcript_path`. Soft-skips (exit 0) when the transcript or `jq` is unavailable (older harness / other assistant) — degrades, never errors.
- **Code-diff gate:** `git diff --name-only HEAD`; skip when empty or docs-only (controls noise — a docs change is not "unverified work").
- **Run-evidence scan:** greps the transcript for Bash invocations matching the stack's run / test / typecheck commands. The command set comes from the existing quality rules (e.g. `tsc --noEmit`, `dotnet build`, `ruff`, `pytest`, `npm test`, `go test`), with a shipped default; degrades to the default when no rule is present. A match ⇒ the work was verified, do not flag the claim.
- **`unresolved-reference` (deterministic subset):** for added `import`/`require`/`include` lines in the diff that name a **relative file path**, check the path resolves on disk; a miss is a reliable, language-agnostic finding the hook emits directly (no LLM). Fuzzy undefined-symbol resolution is left to the skill / the type-checker — the hook only owns the reliable missing-file case.
- **Queue condition:** write a proposal to `.octopus/proposals/<ts>-verification.md` **only when** (code diff) AND (no run detected OR an unresolved file reference found). The proposal records: changed files, whether a run was detected, and any deterministic `unresolved-reference` hits. **Never calls an LLM; never blocks; exit 0.**

**`audit-verification` skill (LLM, cheap-tier, on demand).** Invoked via `/octopus:review-proposals` (not per task). Reads the queued proposal + diff + transcript and emits:

- **`unverified-completion-claim`** — the session asserts done / passing / fixed, but the run-evidence scan found no supporting build/test/typecheck. The LLM judges the claim-vs-evidence nuance (the part bash can't).
- It contextualizes the hook's deterministic `unresolved-reference` hits; it does **not** re-derive them.

Marked **cheap-tier** (mechanical confrontation, not deep reasoning): the skill notes that it runs on the cheapest model (`--model haiku` / each assistant's cheapest), like the Cluster 19 narration.

**Cost contract.** The only recurring (per-task) component is the bash hook — zero tokens. The LLM runs solely on the human-triggered, batched `/octopus:review-proposals`, on the cheap tier. The precise trigger keeps the queue small, which keeps that batched review cheap.

### Migration / Backward Compatibility

Additive — a new Stop hook (registered in `hooks/hooks.json` by `id`, idempotent per RM-040) and a new skill. Reuses the existing `.octopus/proposals/` queue and `/octopus:review-proposals`. No existing surface changes; the hook soft-skips on older harnesses (no transcript) so it is safe everywhere.

## Implementation Plan

1. **`verification-check` Stop hook** — `hooks/stop/verification-check.sh`: transcript soft-skip, code-diff gate, run-evidence scan (rule-sourced command set + default), deterministic missing-file `unresolved-reference`, conditional proposal write. Register in `hooks/hooks.json` (Stop, `id: verification-check`).
2. **`audit-verification` skill** — `skills/audit-verification/SKILL.md`: `unverified-completion-claim` judgment + contextualize the hook's `unresolved-reference` hits; signal-only; cheap-tier; documents the no-block / no-per-task-LLM contract.
3. **Command + bundle** — `commands/audit-verification.md`; register the skill in `bundles/quality.yml` beside `audit-grounding`.
4. **Tests** — hook behavioral fixtures (fake Stop JSON + transcript) and SKILL.md structural assertions.

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [backend-developer, architect]
**Related ADRs**: []
**Skills needed**: [adr, doc-design, audit-grounding]
**Bundle**: introduces the `audit-verification` skill — registers in the `quality` bundle beside `audit-grounding` (no loose skill).

**Constraints**:
- Pure bash for the Stop hook; signal-only — never blocks, exit 0, read-only on the project tree (mirrors `grounding-check.sh`).
- Reuse `.octopus/proposals/` + `/octopus:review-proposals`; do not invent a new queue.
- Language-neutral / stack-agnostic where possible; per-stack run commands come from existing rules, not hardcoded.

## Testing Strategy

- **Hook behavioral fixtures** (a fake Stop JSON pointing at a synthetic transcript, in a git fixture):
  - code diff + transcript with **no** run command → proposal written, records "no run detected".
  - code diff + transcript **with** `tsc`/`pytest`/etc. → **no** proposal (work was verified).
  - diff adding `import './missing'` whose path is absent → proposal carries an `unresolved-reference` hit.
  - docs-only diff → no proposal (gate skips).
  - missing transcript / no `jq` → soft-skip, exit 0, nothing written (degrades).
  - assert the hook **never blocks** (exit 0) and writes nothing outside `.octopus/proposals/`.
- **Skill structural** assertions on `skills/audit-verification/SKILL.md` (frontmatter, the two finding kinds, signal-only, cheap-tier note, `/octopus:review-proposals` path), mirroring `test_knowledge_hygiene.sh`; bundle registration in `bundles/quality.yml`.
- No test invokes an LLM — the hook path is fully deterministic.

## Risks

- **False positives on "did not run".** A wrong "no test ran" signal on a docs-only or trivial change erodes trust. Mitigation: code-diff gate + the signal-only contract (human judges); tune the trigger in the spec.
- **Transcript dependence.** Detecting run evidence from the transcript couples the hook to the harness's transcript format. Mitigation: degrade gracefully — when the transcript is unavailable, queue the review and let the skill judge from the diff alone.

## Changelog

- **2026-05-31** — Initial draft (stub pre-filled from RM-111 + the RM-088 PRD's deferred scope).
- **2026-05-31** — Design session completed. Settled the cost-conscious split: the recurring Stop hook is pure bash (zero LLM), detects `unresolved-reference` (missing-file) deterministically, and queues only when work looks unverified; the `unverified-completion-claim` judgment is a cheap-tier skill run on demand via `/octopus:review-proposals`. Detailed Design, Implementation Plan, Testing filled.
