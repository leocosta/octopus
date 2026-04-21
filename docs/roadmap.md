# Roadmap

This file is the project backlog — ideas that need team discussion
before becoming a spec.

## Two valid entry paths

1. **Roadmap-first** — for ideas that benefit from async brainstorm
   or team validation. Run `/octopus:doc-research <slug>` to produce
   a research doc + new RM entry. The RM graduates to a Spec or RFC
   when work begins; when that happens, update the item's status to
   "in progress" and link the new document.

2. **Spec-first** — for work that already came out of a synchronous
   brainstorm (e.g. the `superpowers:brainstorming` skill) with a
   clear rationale and scope. Create the spec directly via
   `/octopus:doc-spec <slug>` — no RM needed. The spec itself
   carries the "why" and links from the CHANGELOG entry keep the
   history visible.

Use spec-first when the brainstorm already happened; use
roadmap-first when the idea still needs shaping.

---

## Backlog

### Cluster 1 — Reduce tokens loaded per session

- **RM-022** 🔴 High — Lazy skill activation via frontmatter `triggers:`
  (paths / keywords / tools). Agents that concatenate (Copilot, Codex,
  Gemini, OpenCode) replace non-matching skills with a 3-line stub.
  Estimate: −40% to −70% of the output file.
### Cluster 2 — Reduce LLM calls

- **RM-025** 🔴 High — Pre-LLM deterministic pass: audit skills run
  `grep`/`rg` for raw pattern matching first; the LLM only classifies
  severity and writes the human-readable message. Estimate: −60%
  tokens per audit run.
- **RM-026** 🟡 Medium — Cache audit outputs keyed by
  `hash(diff) + skill-version`. Re-running the same audit becomes
  zero-cost until the diff changes.

### Cluster 3 — Accelerate workflow (prioritized — next)

- **RM-027** 🟡 Medium — Bundle / skill diff preview in the Full-mode
  wizard: show impact (lines / approx tokens) before confirming a
  selection.
- **RM-029** 🟡 Medium — Post-merge hook that suggests relevant
  audits based on the diff (touched files + keywords).

### Cluster 4 — Implementation practices

Octopus today covers **static rules** (what the code should be) via
`rules/common/*`. It does not codify **process practices** (how to
get there). The table below shows which code-assistant practices
(from Boris Cherny's Claude Code tips and industry guides) are
covered, partially covered (⚠️), or missing.

| Practice | Today | Planned |
|---|---|---|
| Static coding style (KISS, DRY, YAGNI, naming) | ✅ `rules/common/coding-style.md` | — |
| Quality gates (pre-commit, formatters, typecheck) | ✅ `rules/common/quality.md` | — |
| Security rules (secrets, validation, injection) | ✅ `rules/common/security.md` | — |
| Testing principles (AAA, behavior > implementation) | ✅ `rules/common/testing.md` | — |
| Design patterns (repository, service layer) | ✅ `rules/common/patterns.md` | — |
| **TDD loop** (red → green → refactor → commit) | ❌ | RM-030 |
| **Plan-before-code gate** (approved plan for non-trivial work) | ⚠️ mentioned in CLAUDE.md, not enforced | RM-030 |
| **Verification-before-completion** (run tests before "done") | ❌ | RM-030 |
| **Simplify pass** (post-change review) | ⚠️ `/simplify` mentioned, no skill | RM-030 |
| **Commit cadence** (atomic commits per step) | ⚠️ `core/commit-conventions.md` but no enforcement | RM-030 |
| **Systematic debugging** (reproduce → isolate → fix → regression) | ❌ | RM-031 |
| **Receiving code review** (technical rigor over deference) | ❌ | RM-032 |
| **Ask-before-destructive** (rm, push --force, DROP) | ❌ (Claude prompt has it; Octopus-managed agents don't) | RM-033 |

Cluster 4 closes the gap by shipping an `implement` skill (RM-030),
a `debugging` skill (RM-031), a `receiving-code-review` skill
(RM-032), and a destructive-action guard hook (RM-033).

### Cluster 5 — Superpowers parity (self-sufficient Octopus)

Teams using Octopus today still need the external `superpowers`
plugin for the spec-design → plan → execute loop. The three items
below close that gap so the full workflow lives inside Octopus.

- **RM-037** 🟡 Medium — extend `/octopus:implement` to
  consume a plan file (executing-plans equivalent). Today the
  skill codifies the TDD loop for a single task; this extends
  it to walk a checklist of tasks from `doc-plan`, with
  checkpoints for human review between tasks.

Entry point: RM-035 shipped first, then RM-036. RM-037 is
the smallest increment on top of `implement` and lands last.

---

## In Progress

_No items in progress._

---

## Completed / Rejected

| ID | Title | Resolution | Date |
|----|-------|------------|------|
| RM-001 | Pre-approved permissions in the manifest | completed → [Spec](specs/permissions-manifest.md) | 2026-03-30 |
| RM-002 | PostCompact hook | completed → [Spec](specs/postcompact-hook.md) | 2026-03-30 |
| RM-003 | Claude-Specific Behavior in CLAUDE.md | completed → [Spec](specs/claude-specific-behavior.md) | 2026-03-30 |
| RM-004 | Effort Level in the manifest | completed → [Spec](specs/effort-level-manifest.md) | 2026-03-30 |
| RM-005 | Language rules — behavioral detection + per-project override | completed → [Spec](specs/language-rules.md) | 2026-04-18 |
| RM-006 | Add `tools:` field to role frontmatter | completed → [Spec](specs/tools-field-frontmatter.md) | 2026-04-18 |
| RM-007 | Octopus CLI Tool | completed → [Spec](specs/octopus-cli-tool.md) · [RFC](rfcs/octopus-cli-tool.md) | 2026-04-18 |
| RM-008 | Setup UX unification (shared vocabulary, TUI dispatch, step descriptions) | completed → [Spec](specs/setup-ux-unification.md) | 2026-04-18 |
| RM-009 | GPG-signed release verification | completed → [Spec](specs/signed-releases.md) | 2026-04-18 |
| RM-010 | ~~`octopus migrate` helper~~ | rejected — submodule mode removed in v1.0.0; no migration destination remains | 2026-04-18 |
| RM-011 | Worktree isolation in agents | completed → [Spec](specs/worktree-isolation.md) | 2026-04-18 |
| RM-012 | Auto mode (permissionMode) in the manifest | completed → [Spec](specs/auto-mode.md) | 2026-04-18 |
| RM-013 | Auto-memory + auto-dream in the manifest | completed → [Spec](specs/memory-dream.md) | 2026-04-18 |
| RM-014 | Sandboxing in the manifest | completed → [Spec](specs/sandbox.md) | 2026-04-18 |
| RM-015 | Output styles in the manifest | completed → [Spec](specs/output-styles.md) | 2026-04-18 |
| RM-016 | GitHub Action scaffolding in the manifest | completed → [Spec](specs/github-action.md) | 2026-04-18 |
| RM-017 | /batch skill | completed → [Spec](specs/batch-skill.md) | 2026-04-18 |
| RM-018 | Install scopes — repo vs user | completed → [Spec](specs/install-scopes.md) | 2026-04-18 |
| RM-019 | Dedup the shim embedded in `install.sh` | completed → [Spec](specs/shim-dedup.md) | 2026-04-18 |
| RM-020 | Release signing pipeline | completed → [Spec](specs/release-signing-pipeline.md) | 2026-04-18 |
| RM-021 | Fix pre-existing test failures | completed → [Spec](specs/test-triage.md) | 2026-04-18 |
| RM-028 | `/octopus:audit-all` — parallel run of quality audits | completed → [Spec](specs/audit-all.md) | 2026-04-19 |
| RM-030 | `implement` skill — universal workflow codified as an active-by-default skill (TDD, plan gate, verification, simplify, commit cadence) | completed → [Spec](specs/implement.md) | 2026-04-19 |
| RM-031 | `debugging` skill — universal bug-fix workflow (reproduce, isolate, regression test, document) as an active-by-default skill in `starter` | completed → [Spec](specs/debugging.md) | 2026-04-19 |
| RM-032 | `receiving-code-review` skill — universal PR-feedback discipline (verify, ask for evidence, separate reasoned/preference, never performative, clarify ambiguity) as an active-by-default skill in `starter` | completed → [Spec](specs/receiving-code-review.md) | 2026-04-19 |
| RM-033 | Destructive-action guard hook — PreToolUse/Bash script blocking `rm -rf`, `git push --force`, `DROP TABLE`, `DELETE FROM` without `WHERE`, etc., with `# destructive-guard-ok: <reason>` bypass and `destructiveGuard: false` opt-out | completed → [Spec](specs/destructive-action-guard.md) | 2026-04-19 |
| RM-034 | Task routing — shared decision matrix embedded in `implement` / `debugging` / `receiving-code-review` via canonical fragment at `skills/_shared/task-routing.md`, with drift-prevention test | completed → [Spec](specs/task-routing.md) | 2026-04-20 |
| RM-024 | Dedup shared preambles into `skills/_shared/audit-output-format.md` (3 audit skills referenced shared conventions) | completed → [Spec](specs/audit-output-format.md) | 2026-04-20 |
| RM-023 | `/octopus:compress-skill` — per-skill compression pass with human-approved diff, deterministic cleanup + optional LLM rewrite, invariants on frontmatter/headings/code blocks/test anchors | completed → [Spec](specs/compress-skill.md) | 2026-04-20 |
| RM-035 | `/octopus:doc-design` — interactive spec-design session filling Design, Implementation Plan, Testing, and adaptive (Non-Goals / Risks / Migration) sections via a one-question-at-a-time conversation; HARD-GATE against writing code; chained from `/octopus:doc-spec` | completed → [Spec](specs/doc-design-command.md) | 2026-04-21 |
| RM-036 | `/octopus:doc-plan` — reads a completed spec and writes `docs/plans/<slug>.md` (bite-sized, TDD-style, matches superpowers:writing-plans vocabulary); adaptive "too big / too small" task decomposition; HARD-GATE against writing code; docs-only branch auto-created when starting from main | completed → [Spec](specs/doc-plan-command.md) | 2026-04-21 |
