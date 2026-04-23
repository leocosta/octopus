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

_RM-022 complete. Cluster 1 now has no open items._

### Cluster 2 — Reduce LLM calls

_RM-025 and RM-026 complete. Cluster 2 has no open items._

### Cluster 3 — Accelerate workflow (prioritized — next)

_RM-027 and RM-029 complete. Cluster 3 has no open items._

### Cluster 4 — Implementation practices

_RM-030, RM-031, RM-032, and RM-033 complete. Cluster 4 has no open items._

All process practices are now covered:

| Practice | Coverage |
|---|---|
| Static coding style (KISS, DRY, YAGNI, naming) | ✅ `rules/common/coding-style.md` |
| Quality gates (pre-commit, formatters, typecheck) | ✅ `rules/common/quality.md` |
| Security rules (secrets, validation, injection) | ✅ `rules/common/security.md` |
| Testing principles (AAA, behavior > implementation) | ✅ `rules/common/testing.md` |
| Design patterns (repository, service layer) | ✅ `rules/common/patterns.md` |
| TDD loop + plan gate + verification + simplify + commit cadence | ✅ `implement` skill (RM-030) |
| Systematic debugging | ✅ `debugging` skill (RM-031) |
| Receiving code review | ✅ `receiving-code-review` skill (RM-032) |
| Ask-before-destructive (rm, push --force, DROP) | ✅ destructive-action guard hook (RM-033) |

### Cluster 5 — Superpowers parity (self-sufficient Octopus)

Teams using Octopus today still need the external `superpowers`
plugin for the spec-design → plan → execute loop. The three items
below close that gap so the full workflow lives inside Octopus.

Cluster 5 is complete. All three legs of the
design → plan → execute loop ship inside Octopus: RM-035
(`/octopus:doc-design`), RM-036 (`/octopus:doc-plan`), and
RM-037 (`/octopus:implement --plan`).

---

### Cluster 6 — Local agent orchestration (Paperclip-parity, self-contained)

Teams running multiple AI agents today have no coordination layer without
depending on external SaaS platforms. Cluster 6 adds a self-contained
TUI-driven runtime so Octopus can orchestrate, schedule, and monitor agents
locally — no GitHub Actions, no web server, no cloud account required.

| Item | Description |
|---|---|
| **RM-044** | `octopus control` — TUI dashboard (Python/textual) with agent roster, task queue, live output panel, and scheduler. Process manager launches Claude Code in git worktrees; task queue stored as `.octopus/queue/*.json`; scheduler reads `.octopus/schedule.yml` with cron-style rules. |

### Cluster 7 — Octopus Control UX & completeness

_RM-045..052 complete. Cluster 7 has no open items._

All 8 gaps from the first real-use analysis are resolved (PR #92):

| Item | Resolution |
|---|---|
| RM-045 | Typeahead autocomplete — `SuggestFromList` wired to command bar |
| RM-046 | `RichLog` replaces `Label`; scrollable real-time streaming |
| RM-047 | Animated spinner in agent roster |
| RM-048 | `Scheduler` wired into `on_mount`; scheduled tasks now dispatch |
| RM-049 | Exit code captured via `Popen.poll()`; `failed` state added |
| RM-050 | Selecting done/failed task in queue loads its log into `RichLog` |
| RM-051 | `TaskQueue.cleanup(keep_last)`; auto every 30 ticks; `Ctrl+D` |
| RM-052 | `create_worktree`/`remove_worktree`; `launch(isolate=True)` |

### RM-045 — Typeahead autocomplete for skills in command bar

- **Priority:** 🔴 High
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-04-23
- **Research:** [octopus-control-gaps](research/2026-04-23-octopus-control-gaps.md)

When typing in the command bar, show inline suggestions filtered from the loaded skill
catalog. Uses the existing `SkillMatcher` catalog. Also surfaces the `ambiguous` case
(currently detected but silently ignored) so the user can pick the intended skill.

**Rationale:** Without autocomplete the user has no discovery path for available skills,
making the command bar nearly unusable for anyone who doesn't know skill names by heart.

---

### RM-046 — Real-time scrollable log panel (RichLog)

- **Priority:** 🔴 High
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-04-23
- **Research:** [octopus-control-gaps](research/2026-04-23-octopus-control-gaps.md)

Replace the single `Label` widget (shows only the last line) with a Textual `RichLog`
that streams all output from the running agent and supports scroll. Selecting a different
agent in the roster switches the log view.

**Rationale:** The current single-line output gives no confidence that the agent is doing
anything useful. Users reported being unable to tell if the agent was running at all.

---

### RM-047 — Animated status indicator in agent roster

- **Priority:** 🔴 High
- **Effort:** low
- **Status:** proposed
- **Added:** 2026-04-23
- **Research:** [octopus-control-gaps](research/2026-04-23-octopus-control-gaps.md)

The "Status" column currently shows `● running` as static text. Add an animated spinner
(`LoadingIndicator` or cycling chars) that visually confirms the process is alive. Show
distinct indicators for queued / running / done / failed states.

**Rationale:** Static text gives no confidence of liveness. A moving indicator is the
minimum signal that something is actually happening.

---

### RM-048 — Wire Scheduler into app — dispatch scheduled tasks

- **Priority:** 🔴 High
- **Effort:** low
- **Status:** proposed
- **Added:** 2026-04-23
- **Research:** [octopus-control-gaps](research/2026-04-23-octopus-control-gaps.md)

`scheduler.py` defines a fully working `Scheduler` thread but `app.py` never instantiates
it. The schedule panel in the UI reads `.octopus/schedule.yml` for display only — no tasks
are ever dispatched automatically. Wire `Scheduler` into `on_mount` with `on_fire` calling
`self.queue.enqueue(...)`.

**Rationale:** Schedule-based dispatch is a core Cluster 6 feature per the RM-044 spec.
Shipping the UI without the scheduler makes the schedule panel decorative.

---

### RM-049 — Task `failed` state via exit code capture

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** proposed
- **Added:** 2026-04-23
- **Research:** [octopus-control-gaps](research/2026-04-23-octopus-control-gaps.md)

When `_reap_dead_agents` detects a dead process, it marks all matching running tasks as
`done` regardless of exit code. `ProcessManager` should capture the exit code (via
`subprocess.Popen.wait()` or `os.waitpid`) and the queue should distinguish `done` from
`failed`.

**Rationale:** Without a `failed` state it is impossible to know whether an agent
completed its work or crashed silently.

---

### RM-050 — Log viewer for completed tasks

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** proposed
- **Added:** 2026-04-23
- **Research:** [octopus-control-gaps](research/2026-04-23-octopus-control-gaps.md)

After an agent finishes, the log panel clears. Log files persist at
`.octopus/logs/<role>.log` but are inaccessible from the UI. Add a handler so selecting
a completed task in the queue list loads its log into the RichLog panel (read-only, no
tail).

**Rationale:** Post-run log inspection is essential for debugging failed or unexpected
agent outputs.

---

### RM-051 — Queue cleanup — auto-dequeue done/failed tasks

- **Priority:** 🟡 Medium
- **Effort:** trivial
- **Status:** proposed
- **Added:** 2026-04-23
- **Research:** [octopus-control-gaps](research/2026-04-23-octopus-control-gaps.md)

`TaskQueue.dequeue()` is defined but never called. Tasks accumulate in
`.octopus/queue/` indefinitely. Add a configurable retention policy (e.g. keep last N
completed tasks, or delete after 24 h) and expose a `d` keybind to manually dismiss
selected completed tasks.

**Rationale:** An ever-growing queue directory is a maintenance burden and makes the
queue panel harder to scan.

---

### RM-052 — Worktree isolation per agent

- **Priority:** 🟢 Low
- **Effort:** high
- **Status:** proposed
- **Added:** 2026-04-23
- **Research:** [octopus-control-gaps](research/2026-04-23-octopus-control-gaps.md)

`.octopus/worktrees/` is created at startup but never used — all agents run in the same
`cwd`. For concurrent agents that edit overlapping files, git worktree isolation prevents
conflicts. Requires `git worktree add` on launch, passing the worktree path as `cwd` to
`subprocess.Popen`, and `git worktree remove` on agent exit.

**Rationale:** Without isolation, two concurrent agents editing the same file produce
conflicting writes. Low priority because single-agent usage (the common case) is
unaffected.

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
| RM-037 | `/octopus:implement` gains a `--plan` walker mode that executes a plan file task-by-task, dispatching the existing single-task TDD loop per task, pausing for human review between tasks, flipping checkboxes in place for resume, and closing Cluster 5 | completed → [Spec](specs/implement-plan-walker.md) | 2026-04-21 |
| RM-022 | Lazy skill activation via `triggers:` frontmatter — path/keyword/tool evaluation at setup time in `concatenate_from_manifest`; non-matching skills replaced with 3-line stub; 6 domain-specific skills annotated | completed → [Spec](specs/lazy-skill-activation.md) | 2026-04-22 |
| RM-025 | Pre-LLM deterministic audit pass — shared fragment `_shared/audit-pre-pass.md` + `pre_pass:` frontmatter block; 4-step protocol (candidate files → early exit → line filter → scoped diff) wired into all 4 audit skills | completed → [Spec](specs/pre-llm-audit-pass.md) | 2026-04-22 |
| RM-026 | Audit output cache — content-keyed (`sha256(diff + SKILL.md)`) protocol in `skills/_shared/audit-cache.md`; cache check before inspection, cache write after output; `.gitignore` guard | completed → [Spec](specs/audit-output-cache.md) | 2026-04-22 |
| RM-027 | Skill impact table in Full-mode wizard — `_skill_impact_table()` in `setup-wizard.sh` shows lines and ~tokens per selected skill after multiselect | completed | 2026-04-22 |
| RM-029 | Post-merge audit hook — `pre-push-audit-suggest.sh` + `cli/lib/audit-map.sh` map diff to relevant audits; advisory only, never blocks; installed by setup when `workflow: true` + audit skill present | completed → [Spec](specs/post-merge-audit-hook.md) | 2026-04-22 |
| RM-039 | Bundles setup — declarative YAML bundle files (`bundles/<name>.yml`), `expand_bundles()` preprocessing in `setup.sh`, Quick-mode persona mini-wizard in `setup-wizard.sh`, 7 curated bundles (starter, quality-gates, growth, docs-discipline, cross-stack, dotnet-api, node-api) | completed → [Spec](specs/bundles-setup.md) | 2026-04-19 |
| RM-040 | Hook injection idempotency — `deliver_hooks()` merges by hook `id` instead of full replace; re-running `octopus setup` preserves manually added hooks | completed | 2026-04-22 |
| RM-041 | Lazy activation for remaining 8 skills — `triggers:` frontmatter added to `audit-all`, `backend-patterns`, `batch`, `compress-skill`, `continuous-learning`, `feature-to-market`, `plan-backlog-hygiene`, `release-announce` | completed | 2026-04-22 |
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
