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

_RM-022 complete. No open items._

### Cluster 2 — Reduce LLM calls

_RM-025 and RM-026 complete. No open items._

### Cluster 3 — Accelerate workflow

_RM-027 and RM-029 complete. No open items._

### Cluster 4 — Implementation practices

_RM-030, RM-031, RM-032, and RM-033 complete. No open items._

### Cluster 5 — Superpowers parity (self-sufficient Octopus)

_RM-035, RM-036, RM-037 complete. The design → plan → execute loop ships inside Octopus._

### Cluster 6 — Local agent orchestration

_RM-044 complete. `octopus control` shipped in v1.23.0._

### Cluster 7 — End-to-end pipeline runner

_RM-053 complete. `octopus run` shipped in v1.25.0._

### Cluster 8 — Control & Run UX Overhaul

_RM-054 complete. `octopus ask` shipped in v1.26.0._

### Cluster 9 — Agent Reply (bidirectional interaction)

_RM-055 complete. Agent reply via `--resume` shipped in v1.27.0._

### Cluster 10 — Octopus Control UX & completeness

_RM-045..052 complete. All 8 gaps from the first real-use analysis resolved in PR #92._

### Cluster 11 — Control reliability & ergonomics

_RM-057..063 complete. Shipped in v1.31.0._

### Cluster 12 — Frontend and fullstack bundles

_RM-065 and RM-066 complete. `frontend` and `fullstack` bundles shipped together._

### Cluster 13 — Rules override consistency & formatter hooks

_RM-067..074 complete. Workspace → personal → project rule layering and bundle-aware formatter hooks shipped._

### Cluster 14 — Engineering process skills

_RM-075..084 complete. Shipped across v1.45.0 → v1.49.0 (`doc-align`, `test-tdd`, `refactor-deepen`, `map-system`, `triage-issues`, `doc-prd`, `prototype`, `context-handoff`, `scaffold-skill`, `interview`)._

### Cluster 15 — Claude Code in large codebases (article-parity)

_RM-085..087 complete. Shipped across v1.50.0 → v1.51.0 (`doc-subcontext`, knowledge-update Stop hook, `audit-config`)._

#### Parked (Tier B) — not roadmapped

- **LSP integration** — the article calls out language-server
  symbol navigation as a critical practice for typed languages.
  High value, high effort (probably needs an MCP server wrapping
  language servers per stack). **Acknowledged but not roadmapped**
  pending explicit demand. When demand arrives, open as a
  dedicated planning round.
- **`.claudeignore` template** — small surface; `permissions.deny`
  in settings covers most cases today. Revisit if a user reports
  the gap.
- **Per-subdirectory test/lint commands** — `auto-format.sh`
  already scopes by file path; full-suite test timeouts haven't
  been reported. Revisit if monorepos start hitting it.

### Cluster 16 — Manager multiplier / engineering leadership

_**Complete on `feat/standards-lookup`** — all of RM-089…096 + RM-098 implemented and committed (pending merge/release). Seeds from [research](research/2026-05-30-manager-multiplier.md): extend Octopus so a tech manager can standardize and raise the team's bar across 6+ repos without being the bottleneck._

| RM | Item | Theme |
|----|------|-------|
| RM-089 | `mentor` role — coaching review persona that teaches the *why* | pedagogy |
| RM-090 | `onboarding` skill — ramp a new engineer onto standards + codebase + workflow | pedagogy |
| RM-091 | `definition-of-done` skill + artifact — first-class team DoD | pedagogy |
| RM-092 | `standards` self-serve lookup — "what's our standard for X / why" | pedagogy |
| RM-093 | Team-level `continuous-learning` — recurring PR feedback → rule candidates | knowledge loop |
| RM-094 | `audit-fleet` — cross-repo adoption + drift audit | cross-repo |
| RM-095 | Fleet bootstrap — bulk-apply a standard `.octopus.yml` across repos | cross-repo |
| RM-096 | `tech-lead` bundle — composes the manager kit | bundle |
| RM-098 | `map-system --save` — themed self-contained HTML deck of the repo (overview, business insights, diagrams, API contracts) via frontend-design + launch-release themes; RM-090 depends on it | pedagogy |

---

### Cluster 17 — Consigliere / manager knowledge workspace

_All items **proposed** (added 2026-05-31). Seeds from [research](research/2026-05-31-consigliere-workspace.md): a private `manager-workspace` where a manager digests diverse inputs (Slack, Meet transcripts, Jira, Confluence) into living, grounded memory organized by perennial **contexts** (tree) and cross-cutting **projects**. Where Cluster 16 multiplies the **team**, Cluster 17 multiplies the **manager themselves** — a personal chief-of-staff (`consigliere`). Reuses `audit-grounding` (RM-088) for strict grounding and the continuous-learning pattern for the heuristics loop. Build order: RM-099 → RM-100/101 → RM-102/103; RM-104 is an independent enabler._

| RM | Item | Theme |
|----|------|-------|
| RM-099 | `consigliere` workspace scaffold + bundle — `manager-workspace` layout (sources/contexts/projects/people), `state/journal/playbook` trio convention, `meta.yml` schema, operating README, bundle registration | foundation |
| RM-100 | `digest-source` skill — multi-modal capture (text/PDF/Jira) → immutable snapshot in `sources/` → infer→confirm→preview→write with fan-out pointers; grounded 6-field extraction (status, blockers+owner, decisions, system map, actions+owners, political risk) reusing `audit-grounding` | capture |
| RM-101 | `consigliere` role — the lens/voice: political-risk reading, push/pull application of the playbook, "thinks like you"; the fundamental piece | role |
| RM-102 | `context-status` skill — natural-language consult over materialized state ("how's payments? what's blocked?") | consult |
| RM-103 | `playbook-review` skill + learning loop — seed + capture heuristics from digests, promote to `playbook.md` (reuses continuous-learning / review-proposals) | knowledge loop |
| RM-104 | Atlassian MCP integration — Confluence read + richer Jira; fallback export-PDF until present | integration |

_The workspace's proactive / cross-node / maintenance layer is **not** consigliere-specific — those are operations over any linked markdown tree. They live in **Cluster 19** (knowledge-root operations); the consigliere is one registered root + lens profile (RM-110)._

_Architecture decisions: artifacts generic-in-Octopus + data-in-private-workspace ([ADR-007](adr/007-consigliere-artifact-location.md)); `consigliere` as a separate bundle ([ADR-008](adr/008-consigliere-bundle-separation.md)). Still open → settle in RM-103 spec: playbook scope (per-context vs central)._

---

### Cluster 18 — Release-flow guardrails

_Proposed (added 2026-05-31). Seeded by a real incident on a downstream project: `chore(release): vX.Y.Z` was committed on `develop` before the `develop` → `main` PR merged, leaving the tag unreachable from `main`. The consumer project's runbook teaches the correct order, but that is documentation-level defence. A programmatic guardrail inside Octopus is missing._

| RM | Item | Theme |
|----|------|-------|
| RM-105 | Pre-push hook that rejects `git push --tags` when a release tag (`v*` by default) is not reachable from the main branch (`main` by default). Configurable via `.octopus.yml` (default branch and tag pattern). Explicit bypass via env var for emergencies. Pairs with the consumer runbook as the programmatic layer | hooks |

---

### Cluster 19 — Knowledge-root operations (briefing / synthesize / hygiene)

_Proposed (added 2026-05-31). Seeds from [research](research/2026-05-31-knowledge-root-operations.md): "summarize a base on a cadence", "surface connections that cross nodes", and "audit staleness/orphans/archive" are operations over **any linked markdown tree**, not a manager-specific need. Octopus already has four such roots (`docs/`, the standards set, auto-memory, the consigliere workspace) and already does fragments of this in `plan-backlog-hygiene` / `audit-config` / `doc-align`. One generic engine parameterized by a **knowledge root** replaces that fragmentation; the consigliere becomes one root + lens profile. Build order: RM-106 → RM-107/108/109 (independent) → RM-110._

_**Status: Cluster 19 complete** — RM-106 (#120), RM-107 (#123), RM-108 (#126), RM-109 (#128), RM-110 (#130) all shipped. The knowledge-root engines (`octopus kr`/`hygiene`/`synthesize`/`briefing`/`lens`) operate over any linked markdown tree; the consigliere is one registered root + opus lens profile._

| RM | Item | Theme |
|----|------|-------|
| RM-106 | knowledge-root abstraction — config-declared registry: each root declares path, link convention (`relative` / `[[ ]]` / fan-out / none), archive dir, staleness threshold, optional lens profile, optional read-only source adapter (e.g. Obsidian vault, mirroring `consigliere-connect-atlassian`). Built-in roots: `docs/`, standards set, auto-memory, consigliere workspace. Solves: stops the three engines from each re-implementing "what tree, how linked, where archive" | foundation |
| RM-107 | `knowledge-hygiene` skill — staleness + coverage + broken-link + archive audit over a target root; report + reversible `--fix`. `--gaps` mode adds documentation-coverage detection: nodes missing a known field *and* recurring entities that appear across journals/sources but never got their own node ("what do I talk about and never documented?"). Subsumes the staleness/orphan/link concern that `plan-backlog-hygiene` + `audit-config` cover partially (spec decides fold-as-target vs keep-specialized — no third silo). Solves: bases decay silently; stale state read as current is worse than none, and undocumented topics stay invisible | maintenance |
| RM-108 | `knowledge-synthesize` skill — surface connections that cross nodes of a root (shared blocker, doc contradicting an ADR, forgotten-but-relevant note); seeds/repairs the link convention where missing. Strongest targets: auto-memory (`[[ ]]`, built to be linked) and `docs/` (specs vs ADRs). Solves: every root is a silo; cross-node patterns only surface if you already suspect them | cross-node traversal |
| RM-109 | `knowledge-briefing` skill — generated summary over a target root on a cadence; `--daily` (attention deltas), `--weekly` (rollup). Read-only, grounded; cadence hosted by `/schedule`/`/loop`. Strongest targets: consigliere workspace, `docs/`+roadmap. Solves: a base only speaks when spoken to — nothing surfaces "what changed / what needs you today" | proactive output |
| RM-110 | consigliere lens profile — register the private workspace as a root (fan-out links, archive, threshold) + attach the consigliere lens (political-risk surfacing, per-node `playbook.md`, "thinks like you" voice) so RM-107…109 output reads like the consigliere when target = workspace; honors ADR-007 write-guard. Solves: delivers the manager proactive/synthesis/maintenance layer by reusing the engines, not duplicating them | consigliere |

_RM-106 has a [spec](specs/knowledge-root-registry.md). Architecture decisions settled: config scoping per-repo/per-user with a load-time guard ([ADR-009](adr/009-knowledge-root-config-scoping.md)); hygiene boundary — fold `plan-backlog-hygiene`, keep `audit-config` separate ([ADR-010](adr/010-knowledge-hygiene-boundary.md))._

---

### Cluster 20 — Completion-verification guardrail

_Proposed (added 2026-05-31). Closes the two failure modes the RM-088 PRD ([docs/specs/local-guardrails-quality-style-grounding.md](specs/local-guardrails-quality-style-grounding.md)) explicitly deferred. RM-088 shipped the **syntactic block** (`guardrails` bundle) and the **semantic signal** (`audit-grounding` skill + `grounding-check` Stop hook); the third side of the local-guardrail triad — the **verification signal** — was left out of scope: "non-existent APIs / missing files" and the "claimed done without running" failure mode. An agent can assert a task is complete or passing without ever executing the build/test/typecheck, and reference a symbol the type-checker would reject — neither is caught today (the type-checker only catches it if it is run)._

| RM | Item | Theme |
|----|------|-------|
| RM-111 | `audit-verification` skill + `verification-check` Stop hook — signal-only, mirroring `audit-grounding`'s shape. At task end on a code diff, the hook queues a review; the skill confronts the session's completion claim against run evidence (did the build/test/typecheck actually run this session?) and flags unresolved-symbol / missing-file references the type-checker would reject. Never blocks (the syntactic gate already blocks at commit; this signals the "claimed done without running" gap). Registers in `quality` beside `audit-grounding`; pairs with the `guardrails` syntactic block | local guardrail |

_Seed: the [RM-088 PRD](specs/local-guardrails-quality-style-grounding.md)'s Out-of-Scope section._

_**Status: Cluster 20 complete** — RM-111 shipped in #134. The local-guardrail triad is closed: syntactic **block** (`guardrails`) + semantic **signal** (`audit-grounding`) + verification **signal** (`audit-verification`). The recurring hook is zero-LLM; the judgment is cheap-tier on demand via `/octopus:review-proposals`._

---

## In Progress

_RM-088 (`audit-grounding`) shipped in v1.69.0. **Cluster 16** (manager-multiplier) is **complete on `feat/standards-lookup`** — all implemented & committed, pending merge/release: RM-089 (`mentor`), RM-090 (`onboarding`), RM-091 (`definition-of-done`), RM-092 (`standards`), RM-093 (team `continuous-learning`), RM-094 (`audit-fleet`), RM-095 (`fleet-bootstrap`), RM-096 (`tech-lead` bundle), RM-098 (`map-system` complete-mode deck). ADRs 002–006 recorded. See [research](research/2026-05-30-manager-multiplier.md)._

---

## Completed / Rejected

| ID | Title | Resolution | Date |
|----|-------|------------|------|
| RM-111 | `audit-verification` — verification signal closing the RM-088-deferred failure modes; zero-LLM `verification-check` Stop hook (code-diff gate, transcript run-evidence scan, deterministic missing-file `unresolved-reference`) + cheap-tier `unverified-completion-claim` skill on demand; signal-only | completed → [Spec](specs/audit-verification.md), #134 | 2026-05-31 |
| RM-106 | Knowledge-root registry — defaults file + loader + `octopus kr` subcommand (list/meta/nodes/links/archive); ADR-009 config scoping, ADR-010 hygiene boundary | completed → [Spec](specs/knowledge-root-registry.md), #120 | 2026-05-31 |
| RM-107 | `knowledge-hygiene` — hybrid audit over any knowledge root (staleness/broken-link/orphan/archive-drift + `--gaps`, reversible `--fix`); deterministic core + `octopus hygiene` + SKILL.md; ADR-010 plan-backlog supersession | completed → [Spec](specs/knowledge-hygiene.md), #123 | 2026-05-31 |
| RM-108 | `knowledge-synthesize` — hybrid engine surfacing cross-node connections (shared-target / co-mention / `--node` lexical-overlap); language-neutral entity core, contradiction judged by the SKILL.md; `octopus synthesize` | completed → [Spec](specs/knowledge-synthesize.md), #126 | 2026-05-31 |
| RM-109 | `knowledge-briefing` — proactive cadence summary (change-delta since a per-root user-scoped watermark, composing hygiene/synthesize); `--daily` advances, `--weekly` window-only; grounded cheap-tier narration; `octopus briefing` | completed → [Spec](specs/knowledge-briefing.md), #128 | 2026-05-31 |
| RM-110 | `consigliere-lens` — wrapper reframing the engines through the consigliere lens over the private workspace (`octopus lens` surfaces playbook + political-risk; opus voice; read-only ADR-007); closes Cluster 19 | completed → [Spec](specs/consigliere-lens.md), #130 | 2026-05-31 |
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
| RM-031 | `debug` skill — universal bug-fix workflow (reproduce, isolate, regression test, document) as an active-by-default skill in `starter` | completed → [Spec](specs/debug.md) | 2026-04-19 |
| RM-032 | `respond-to-review` skill — universal PR-feedback discipline (verify, ask for evidence, separate reasoned/preference, never performative, clarify ambiguity) as an active-by-default skill in `starter` | completed → [Spec](specs/respond-to-review.md) | 2026-04-19 |
| RM-033 | Destructive-action guard hook — PreToolUse/Bash script blocking `rm -rf`, `git push --force`, `DROP TABLE`, `DELETE FROM` without `WHERE`, etc., with `# destructive-guard-ok: <reason>` bypass and `destructiveGuard: false` opt-out | completed → [Spec](specs/destructive-action-guard.md) | 2026-04-19 |
| RM-034 | Task routing — shared decision matrix embedded in `implement` / `debug` / `respond-to-review` via canonical fragment at `skills/_shared/task-routing.md`, with drift-prevention test | completed → [Spec](specs/task-routing.md) | 2026-04-20 |
| RM-024 | Dedup shared preambles into `skills/_shared/audit-output-format.md` (3 audit skills referenced shared conventions) | completed → [Spec](specs/audit-output-format.md) | 2026-04-20 |
| RM-023 | `/octopus:compress-skill` — per-skill compression pass with human-approved diff, deterministic cleanup + optional LLM rewrite, invariants on frontmatter/headings/code blocks/test anchors | completed → [Spec](specs/compress-skill.md) | 2026-04-20 |
| RM-035 | `/octopus:doc-design` — interactive spec-design session filling Design, Implementation Plan, Testing, and adaptive (Non-Goals / Risks / Migration) sections via a one-question-at-a-time conversation; HARD-GATE against writing code; chained from `/octopus:doc-spec` | completed → [Spec](specs/doc-design-command.md) | 2026-04-21 |
| RM-036 | `/octopus:doc-plan` — reads a completed spec and writes `docs/plans/<slug>.md` (bite-sized, TDD-style, matches superpowers:writing-plans vocabulary); adaptive "too big / too small" task decomposition; HARD-GATE against writing code; docs-only branch auto-created when starting from main | completed → [Spec](specs/doc-plan-command.md) | 2026-04-21 |
| RM-037 | `/octopus:implement` gains a `--plan` walker mode that executes a plan file task-by-task, dispatching the existing single-task TDD loop per task, pausing for human review between tasks, flipping checkboxes in place for resume, and closing Cluster 5 | completed → [Spec](specs/implement-plan-walker.md) | 2026-04-21 |
| RM-022 | Lazy skill activation via `triggers:` frontmatter — path/keyword/tool evaluation at setup time in `concatenate_from_manifest`; non-matching skills replaced with 3-line stub; 6 domain-specific skills annotated | completed → [Spec](specs/lazy-skill-activation.md) | 2026-04-22 |
| RM-025 | Pre-LLM deterministic audit pass — shared fragment `_shared/audit-pre-pass.md` + `pre_pass:` frontmatter block; 4-step protocol (candidate files → early exit → line filter → scoped diff) wired into all 4 audit skills | completed → [Spec](specs/pre-llm-audit-pass.md) | 2026-04-22 |
| RM-026 | Audit output cache — content-keyed (`sha256(diff + SKILL.md)`) protocol in `skills/_shared/audit-cache.md`; cache check before inspection, cache write after output; `.gitignore` guard | completed → [Spec](specs/audit-output-cache.md) | 2026-04-22 |
| RM-027 | Skill impact table in Full-mode wizard — `_skill_impact_table()` in `setup-wizard.sh` shows lines and ~tokens per selected skill after multiselect | completed | 2026-04-22 |
| RM-029 | Post-merge audit hook — `pre-push-audit-suggest.sh` + `cli/lib/audit-map.sh` map diff to relevant audits; advisory only, never blocks; installed by setup when `workflow: true` + audit skill present | completed → [Spec](specs/post-merge-audit-hook.md) | 2026-04-22 |
| RM-039 | Bundles setup — declarative YAML bundle files (`bundles/<name>.yml`), `expand_bundles()` preprocessing in `setup.sh`, Quick-mode persona mini-wizard in `setup-wizard.sh`, 7 curated bundles (starter, quality-gates, growth, docs-discipline, cross-stack, dotnet-api, node-api) | completed → [Spec](specs/bundles-setup.md) | 2026-04-19 |
| RM-040 | Hook injection idempotency — `deliver_hooks()` merges by hook `id` instead of full replace; re-running `octopus setup` preserves manually added hooks | completed | 2026-04-22 |
| RM-041 | Lazy activation for remaining 8 skills — `triggers:` frontmatter added to `audit-all`, `backend-patterns`, `batch`, `compress-skill`, `continuous-learning`, `launch-feature`, `plan-backlog`, `launch-release` | completed | 2026-04-22 |
| RM-042 | `--dry-run` mode for `octopus setup` — `OCTOPUS_DRY_RUN` guard in every `deliver_*()` function prints `[dry-run] would …` without writing; `tests/test_dry_run.sh` with 16 cases | completed | 2026-04-22 |
| RM-043 | `octopus uninstall` — guided teardown removing symlinks, agent files, slash commands, hooks/permissions from `settings.json`, gitignore entries; optional removal of `.env.octopus`, GitHub Action, manifest | completed | 2026-04-22 |
| RM-038 | `social-media` role — Senior Social Media Strategist persona with platform-native X/Instagram copy, approval-gated publishing, visual asset briefs, and evidence hierarchy; `scripts/x_post.py` for local credential-safe publishing | completed → [Spec](specs/social-media-role.md) | 2026-04-04 |
| RM-045 | Typeahead autocomplete for skills in command bar | completed → PR #92 | 2026-04-23 |
| RM-046 | Real-time scrollable log panel (RichLog) | completed → PR #92 | 2026-04-23 |
| RM-047 | Animated status indicator in agent roster | completed → PR #92 | 2026-04-23 |
| RM-048 | Wire Scheduler into app — dispatch scheduled tasks | completed → PR #92 | 2026-04-23 |
| RM-049 | Task `failed` state via exit code capture | completed → PR #92 | 2026-04-23 |
| RM-050 | Log viewer for completed tasks | completed → PR #92 | 2026-04-23 |
| RM-051 | Queue cleanup — auto-dequeue done/failed tasks | completed → PR #92 | 2026-04-23 |
| RM-052 | Worktree isolation per agent | completed → PR #92 | 2026-04-23 |
| RM-044 | `octopus control` TUI dashboard — agent roster, task queue, scheduler, live logs, worktree isolation | completed → [Spec](specs/octopus-control.md) | 2026-04-23 |
| RM-053 | Pipeline runner — enriched plan format, `PipelineRunner` DAG executor, `octopus run` entry point | completed → v1.25.0 | 2026-04-24 |
| RM-054 | Control & Run UX Overhaul — `octopus ask`, `@role:` prefill, mini-feed roster, cursor-focus output | completed → v1.26.0 | 2026-04-24 |
| RM-055 | Agent reply via `--resume` — session capture, `[r]` keybinding, `launch_resume()`, reply in log | completed → v1.27.0 | 2026-04-24 |
| RM-056 | Control polish (v1.28–v1.30) — animated queue spinner, output panel expanded, `--dangerously-skip-permissions`, zombie process fix, awaiting-reply roster state, multi-task queue per agent with `+N queued` badge | completed → v1.28.0–v1.30.0 | 2026-04-25 |
| RM-057 | Per-task log files — `<role>-<task-id>.log` with `<role>.log` symlink | completed → v1.31.0 | 2026-04-25 |
| RM-058 | Cancel queued task from TUI — `x` keybind | completed → v1.31.0 | 2026-04-25 |
| RM-059 | Retry failed task from TUI — `e` keybind | completed → v1.31.0 | 2026-04-25 |
| RM-060 | Notification on agent completion — terminal bell + notify-send/osascript | completed → v1.31.0 | 2026-04-25 |
| RM-061 | `octopus ask --reply` — CLI session continuation | completed → v1.31.0 | 2026-04-25 |
| RM-062 | Model override in TUI command bar — `--model opus\|sonnet\|haiku` | completed → v1.31.0 | 2026-04-25 |
| RM-063 | Daemon mode — `octopus control --daemon start/stop/status` | completed → v1.31.0 | 2026-04-25 |
| RM-064 | `content-images` skill — AI image generation for blog covers, Instagram posts, and carousels with social-media agent integration | completed → [Spec](specs/2026-04-27-content-images-skill-design.md) | 2026-04-27 |
| RM-067 | Symlink mode: incluir `.local.md` do `.octopus/rules/` no delivery — `deliver_rules` now symlinks project `.local.md` overrides alongside defaults; live without re-run | completed | 2026-05-16 |
| RM-068 | Personal override layer via `~/.octopus/rules/` — new precedence layer between Octopus defaults and project overrides for both symlink and concatenate modes | completed | 2026-05-16 |
| RM-069 | Workspace/shared repo como fonte de rules — `workspace:` key in `.octopus.yml` adds a team-wide rule layer; precedence: defaults → workspace → personal → project | completed | 2026-05-16 |
| RM-070 | Concatenate mode: git hooks para re-assembly automático — `post-merge`/`post-checkout` hooks detect `.local.md` changes and re-run setup automatically | completed | 2026-05-16 |
| RM-071 | Atualizar manifesto do Copilot para `native_rules: true` — rules now symlinked to `.github/instructions/` as `.instructions.md` files | completed | 2026-05-16 |
| RM-072 | Atualizar manifesto do Codex para `native_rules: true` — rules now symlinked to `.codex/rules/` | completed | 2026-05-16 |
| RM-073 | Setup auto-configura todos os assistentes para apontar para as rules — `concatenate_from_manifest` injects a "## Coding Rules" section with rule paths when `native_rules: true` | completed | 2026-05-16 |
| RM-074 | Bundle-aware formatter hooks — `deliver_hooks` filters by `stacks` field; `.octopus/hooks/hooks.local.json` overrides defaults; `auto-format.sh` dotnet fix | completed | 2026-05-16 |
| RM-065 | `frontend` bundle — `frontend-patterns` + `test-component` skills (reusing `test-e2e`) wired with the `frontend-developer` role; bilingual site docs | completed | 2026-05-27 |
| RM-066 | `fullstack` bundle — `backend` ∪ `frontend` ∪ `review-contracts` for monorepos; `test-e2e` de-duplicated by the expander | completed | 2026-05-27 |
| RM-075 | `doc-align` skill — interactive grilling against CONTEXT.md glossary and ADRs | completed → v1.45.0 | 2026-05-19 |
| RM-076 | `test-tdd` skill — standalone red-green-refactor loop extracted from `implement` | completed → v1.45.0 | 2026-05-19 |
| RM-077 | `refactor-deepen` skill — find shallow modules and deepening opportunities | completed → v1.45.0 | 2026-05-19 |
| RM-078 | `map-system` skill + command — one-shot domain-language map of unfamiliar code | completed → skill v1.45.0, command v1.46.0 | 2026-05-19 |
| RM-079 | `triage-issues` skill + command — state-machine triage with mandatory AI disclaimer | completed → v1.45.0 | 2026-05-19 |
| RM-080 | `doc-prd` skill + command — synthesise conversation into PRD without re-interview | completed → v1.45.0 | 2026-05-19 |
| RM-081 | `prototype` skill + command — throwaway code answering one design question | completed → v1.45.0 | 2026-05-19 |
| RM-082 | `context-handoff` skill + command — compact session into handoff doc in OS tmp | completed → v1.45.0 | 2026-05-19 |
| RM-083 | `scaffold-skill` skill + command — create new Octopus skills with bundle registration | completed → skill v1.45.0, command v1.48.0 | 2026-05-19 |
| RM-084 | `interview` skill + command — one-question-at-a-time requirements walkthrough | completed → v1.47.0 | 2026-05-19 |
| RM-085 | `doc-subcontext` skill + command — subdirectory CLAUDE.md tooling | completed → v1.50.0 | 2026-05-19 |
| RM-086 | Stop hook for CLAUDE.md / knowledge update proposals + `/octopus:review-proposals` | completed → v1.51.0 | 2026-05-19 |
| RM-087 | `audit-config` skill + command — configuration freshness audit | completed → v1.50.0 | 2026-05-19 |
| RM-088 | `audit-grounding` skill + `grounding-check` Stop hook — signal-only divergence from the source of truth (invented conventions, unsupported domain facts) | completed → v1.69.0 | 2026-05-30 |
