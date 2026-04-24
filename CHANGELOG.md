# Changelog

All notable changes to this project will be documented in this file.

## [1.27.1] - 2026-04-24

This patch release fixes two `octopus control` reliability issues. 🐛

**Stuck "running" tasks** — tasks whose processes had died were left indefinitely in the queue with a "running" status, making `Ctrl+D` cleanup ineffective. The TUI now reconciles process state against the queue on startup and before every cleanup sweep, so stale entries are correctly transitioned to "done" or "failed".

**Empty agents roster** — opening `octopus control` showed no agents unless at least one was already running. The roster now loads all roles configured in `.claude/agents/` at startup and displays them as idle, giving you the full picture from the moment the dashboard opens.

## [1.27.0] - 2026-04-24

✨ **Agent reply — bidirectional interaction via session resume**

Agents launched by `octopus control` and `octopus ask` can now be replied to, enabling multi-turn conversations without restarting a task.

Under the hood, agents now run with `--output-format=stream-json --verbose`. A background parser thread reads the JSONL output, extracts the `session_id` from the first event, and writes it to `.octopus/sessions/<role>.session`. Plain text is still written to the log as before, so streaming and the Output panel are unaffected.

A new `[r]eply` keybinding in the TUI opens the command bar pre-filled with `↩ <role>: ` when the selected agent has a resumable session. Submitting the reply calls `launch_resume()`, which runs `claude --resume <session_id> --print "<reply>"` and appends the new turn to the existing log with a `── reply ──` separator. The Output panel streams the resumed session live. Multiple back-and-forth turns are supported — each turn captures a new `session_id`. Agents with a resumable session show a subtle `↩` indicator in the roster.

`octopus ask` prints the session file path at the end of every run so users know a TUI reply is available without opening the dashboard.

## [1.26.0] - 2026-04-24

✨ **Control & Run UX overhaul — `octopus ask`, `@role:` delegation, mini-feed, pipeline progress**

The `octopus control` and `octopus run` experience is now significantly more usable with six targeted UX improvements.

A new `octopus ask <role> "task"` command provides terminal-first delegation: it launches a specific agent and streams its log to stdout in real time, printing timestamps on each output line and a `✓ done` / `✗ failed` summary with elapsed time at the end. `Ctrl+C` during streaming prompts `[k]ill  [d]etach  [c]ancel` so agents can be detached to run in the background and later picked up by `octopus control`.

The TUI command bar now understands `@role:` prefix syntax — typing `@tech-writer: write the ADR` routes the task to the correct agent regardless of cursor position. Selecting an idle agent in the roster and pressing `a` (or Enter) pre-fills `@<role>: ` in the command bar so delegation is a single gesture. The agents roster now shows the last line of each agent's log inline, dimmed, so users can monitor all parallel agents at a glance without switching the output panel. Navigating the agents table with arrow keys now updates the Output panel to that agent's full log in real time.

✨ `pipeline.py` now emits structured progress lines throughout execution — `→ id  agent  body` on task start, `✓/✗ id  agent  Ns` on completion, and a final `✓/✗ pipeline done  Ns` summary — so `octopus run` gives live per-task feedback instead of silence.

🔧 A named constant `_LOG_WAIT_POLL` was extracted and a missing-log guard was added to `ask.py` to handle the case where an agent fails to start.

## [1.25.0] - 2026-04-23

✨ **Pipeline runner — `octopus run`, DAG executor, and control UI overhaul**

The centerpiece of this release is the end-to-end pipeline runner: starting from a requirement in any form (free text, GitHub issue, or existing spec), Octopus now orchestrates multiple agents in parallel all the way to an automatically opened PR. The new `octopus run` command serves as a unified entry point, chaining `doc-research → doc-plan → execution → review gate → PR` without manual intervention between steps.

The execution core lives in `cli/control/pipeline.py`, which reads the new enriched plan format — a `pipeline:` YAML frontmatter block with per-task `agent` and `depends_on` fields — and builds a dependency graph (DAG). Tasks with no shared dependencies run in parallel in isolated git worktrees; dependent tasks wait for their predecessors to finish. Plan checkboxes are ticked in real time as tasks complete, and a reviewer agent is dispatched automatically when `review_skill` is configured. The `octopus control --plan <file>` flag exposes the runner non-interactively with `--dry-run` support.

`/octopus:doc-plan` gained a Step 3b that auto-generates the pipeline frontmatter, inferring the responsible agent from task keywords (migration/endpoint/API → `backend-specialist`, component/UI/form → `frontend-specialist`, doc/README/ADR → `tech-writer`, review/audit → `reviewer`) and the dependency chain between tasks. The `plan-skeleton.md` template was updated to include the `pipeline:` block by default.

🎨 The `octopus control` TUI received a full visual overhaul: the PID column was replaced by elapsed time with a spinner (e.g. `⠙ 2m34s`); all panel borders now show dynamic titles (`Agents`, `Queue  2 running · 1 waiting`, `Output · backend-specialist · live`); layout proportions were corrected (queue `2fr`, schedule `1fr`); background darkened to `#080c14` with visible but subtle borders; the 🐙 emoji was added to the window title. 🐛 The redundant ID column was removed from the Schedule panel.

🔧 `.worktrees/` was added to `.gitignore` to support the worktree isolation system.

## [1.24.0] - 2026-04-23

✨ This release completes the `octopus control` TUI dashboard with the UX and correctness gaps identified during first real use (RM-045 to RM-052).

The log panel now uses a scrollable `RichLog` widget that streams all agent output in real time — replacing the single-line `Label` that showed only the last line. The agent roster gains an animated spinner to visually confirm that a process is alive. Selecting a completed or failed task in the queue list loads its full log from disk into the same panel, making post-run inspection straightforward.

Skill discovery in the command bar is now driven by `SuggestFromList` typeahead: typing `/` filters available skills inline. Ambiguous natural-language matches surface a warning instead of silently dispatching to the wrong skill; single-match NL hits show the resolved skill in the input for confirmation before enqueue.

On the correctness side, `ProcessManager` now stores `Popen` objects and exposes `exit_code()` via `poll()`. Dead agents are marked `done` or `failed` based on their actual exit code rather than always assumed successful. The `Scheduler` thread — previously defined but never instantiated — is now wired into `on_mount` and dispatches tasks whenever a `.octopus/schedule.yml` entry fires. Queue cleanup lands as `TaskQueue.cleanup(keep_last)`, running automatically every 30 polling ticks and exposed as `Ctrl+D` for manual use. The `worktrees/` directory that `ProcessManager` created at startup but never used is now backed by working `create_worktree` / `remove_worktree` helpers; `launch(isolate=True)` runs agents in a dedicated git worktree and cleans it up on reap.

📝 The gap analysis that prompted these changes is documented in `docs/research/2026-04-23-octopus-control-gaps.md`.

## [1.23.3] - 2026-04-22

🐛 Fixes slash commands in `octopus control` being sent with the wrong format. `_build_prompt` was reading key `"raw_prompt"` (which doesn't exist in the queue JSON) instead of `"prompt"`, and was building `/security-scan` instead of `/octopus:security-scan` — the namespace Claude Code uses for installed Octopus commands. Both bugs meant queued skill tasks ran without the skill context.

## [1.23.2] - 2026-04-22

🐛 Fixes three bugs that made `octopus control` non-functional after opening:

Tasks submitted via the command bar were enqueued but never executed — the TUI had no dispatch loop connecting the queue to `ProcessManager.launch()`. A `_poll()` method now runs every 2 seconds, dispatching the next queued task per role, reaping finished PIDs, and refreshing the roster and queue panels automatically.

The async log tailer had no `await asyncio.sleep()`, causing it to busy-loop and block Textual's event loop entirely. The replacement `_stream_log()` coroutine waits 200 ms between empty reads and stops tailing once the agent process exits.

`SkillMatcher` was pointed at `.octopus/skills/` (which does not exist) instead of `.claude/skills/` where Octopus installs skills. Slash commands still work without this fix, but natural-language keyword matching was silently producing an empty catalog.

## [1.23.1] - 2026-04-22

🐛 Fixes `octopus control` failing with `No module named 'cli'` when invoked outside the repository root. The fix sets `PYTHONPATH` to the parent of `CLI_DIR` before launching `python3 -m cli.control.app`, so module resolution works correctly regardless of the current working directory.

## [1.23.0] - 2026-04-22

✨ This release delivers **RM-044 — `octopus control`**, a self-contained TUI dashboard (Python/textual) that lets a single developer orchestrate multiple Claude Code agent sessions locally without external infrastructure.

The new `octopus control` subcommand opens a four-panel terminal UI: an **AgentRoster** that polls running agent PIDs every second and adopts orphaned sessions on startup; a **TaskQueue** backed by JSON files under `.octopus/queue/` with nanosecond-precision IDs for collision-free concurrent writes; a **SchedulePanel** driven by a background cron thread that reads `.octopus/schedule.yml` and fires tasks on `daily HH:MM` or weekday rules; and an **OutputPanel** that tails agent log files asynchronously. A command bar (bound to `a`) accepts both slash commands (`/security-scan src/auth/`) and natural-language prompts, resolved to a skill and model by the new `SkillMatcher` — which reads skill frontmatter and respects per-skill model overrides over the role default. Pressing `q` with agents running prompts a `stop / detach / cancel` choice so sessions are never silently killed. The UI is styled with the Octopus palette (`#7B2FBE` accent, `#00B4D8` ocean, `#1a1a2e` background) and panel focus borders.

The process manager launches Claude Code as a subprocess in an isolated git worktree under `.octopus/worktrees/<role>/`, writes a PID file, and streams output to a per-role log. Fifteen new tests cover the full stack: `bash tests/test_control.sh` exercises CLI routing and the integration path for `adopt_orphans`; `pytest` covers launch/kill, queue ops, cron firing, and all skill-matcher branches including ambiguous NL input and empty strings.

🐛 The hook delivery system was hardened: `deliver_hooks()` now merges by hook `id` instead of replacing the full array, so re-running `octopus setup` no longer clobbers manually added hooks. ✨ Eight additional skills (`audit-all`, `backend-patterns`, `batch`, `compress-skill`, `continuous-learning`, `feature-to-market`, `plan-backlog-hygiene`, `release-announce`) gained `triggers:` frontmatter, completing lazy activation coverage. 🔧 A `--dry-run` mode was added to `octopus setup` — every `deliver_*()` function checks `OCTOPUS_DRY_RUN` and prints what it would do without touching the filesystem, backed by 16 test cases.

## [1.22.0] - 2026-04-22

✨ This release closes three roadmap items that together make Octopus audits faster and more automatic.

The audit pipeline gains a **content-keyed output cache** (RM-026): each run hashes the scoped diff against the skill's own SKILL.md, stores the result under `.octopus/cache/<skill>/<key>.md`, and replays it instantly on re-runs without calling the LLM. The shared protocol lives in `skills/_shared/audit-cache.md` and is referenced by all four audit skills. A `.gitignore` guard is applied automatically so cache files are never committed.

The Full-mode setup wizard now shows a **skill impact table** before the user confirms their selection (RM-027): the new `_skill_impact_table()` helper in `setup-wizard.sh` reads `wc -l` from each skill's SKILL.md and displays lines and an estimated token count (~4 tokens/line), making the cost of a selection visible upfront.

✨ A new advisory **pre-push git hook** (RM-029) rounds out the release. `cli/lib/audit-map.sh` is a pure bash library that parses the patterns.md cascade for each audit skill — path tokens tested against changed file paths, content regexes tested against added/removed lines — and emits the matched audit names in criticality order. `hooks/git/pre-push-audit-suggest.sh` uses this library to print a suggestion blocklet before every push, listing which Octopus audits the diff is likely to need. The hook is installed by `octopus setup` when `workflow: true` and at least one audit skill is present; it is advisory only, never blocks, and can be skipped with `OCTOPUS_SKIP_AUDIT_HOOK=1` or disabled repo-wide with `postMergeAuditHook: false` in `.octopus.yml`. Chain-mode preserves any pre-existing `pre-push` hook. The `patterns.md` files for `money-review`, `tenant-scope-audit`, and the newly created `security-scan` were migrated to the standard `## Path tokens` / `## Content regex` schema the library expects.

## [1.21.0] - 2026-04-22

✨ This release ships **RM-025 — Pre-LLM Audit Pass**, completing the token-reduction arc started in v1.20.0. All four audit skills (`money-review`, `security-scan`, `cross-stack-contract`, `tenant-scope-audit`) now run a deterministic grep phase before handing the diff to the LLM. A new shared fragment `skills/_shared/audit-pre-pass.md` defines the four-step protocol: filter candidate files from `git diff --name-only`, exit early if none match, apply an optional line-level filter, and produce a scoped diff containing only relevant files.

Each skill declares its domain patterns via a new `pre_pass:` frontmatter block alongside `triggers:`. On PRs with no relevant files the skill exits immediately with "no changes detected", avoiding any LLM call. 📝 The spec was published separately in PR #73 before implementation, following the doc-design → doc-plan → implement workflow.

## [1.20.0] - 2026-04-22

✨ This release ships **RM-022 — Lazy Skill Activation**, the first item
from Cluster 1 (Reduce tokens loaded per session). A new `triggers:`
frontmatter block in `SKILL.md` lets each skill declare when it is
relevant — by file paths, keywords, or manifest tools. When
`octopus setup` generates a concatenated agent output (Copilot, Codex,
Gemini, OpenCode), skills whose triggers don't match the project are
replaced with a compact 3-line stub instead of their full content. Skills
without a `triggers:` block are always included in full, preserving
complete backward compatibility.

Six domain-specific skills ship with trigger annotations out of the box:
`e2e-testing`, `dotnet`, and `cross-stack-contract` activate on file
paths (spec files, `.csproj`, OpenAPI docs); `security-scan`,
`money-review`, and `tenant-scope-audit` activate on keywords in README
and project metadata. Dog-food against this repo (bash/markdown, no
framework code) measured −1,326 lines saved across the 6 guarded skills,
exceeding the RM-022 target of ≥ 40% reduction in output size for
typical projects.

📝 A completed design spec for RM-022 was added to `docs/specs/` via
`/octopus:doc-design`.

## [1.19.0] - 2026-04-21

This release completes **Cluster 5**, bringing the full spec-design → plan →
execute workflow natively into Octopus — no external `superpowers` plugin
required for the design loop.

✨ Three new slash commands land in this release. `/octopus:doc-design` opens
an interactive spec-design session that walks through Design, Implementation
Plan, Testing Strategy, and adaptive sections (Non-Goals, Risks, Migration)
via a one-question-at-a-time conversation, finishing with a self-review pass
and an automatic docs-only branch commit. `/octopus:doc-plan` reads a
completed spec and writes a `docs/plans/<slug>.md` plan file using
bite-sized, TDD-style tasks with adaptive decomposition heuristics ("too big"
and "too small" guards) and a 15-task split warning. `/octopus:implement`
gains a `--plan PATH` walker mode that executes a plan file task-by-task:
it dispatches the existing single-task TDD loop per task, flips each task's
checkboxes in place after the commit (strategy documented in
`docs/adr/001-plan-walker-checkbox-commit.md`), and pauses for human review
between tasks with a `Continue / stop / redo-current` prompt. A
`--resume-from TaskN` flag allows picking up an interrupted session.
HARD-GATE: the walker never pushes, never opens PRs, never creates branches.

🐛 A fix to `/octopus:doc-design` clarifies the HARD-GATE wording (docs-only
branches are explicitly permitted) and adds automatic docs-only branch
creation when the session starts on `main` or `master`, preventing accidental
spec commits directly to the main branch.

📝 Design sessions produced specs for two upcoming Cluster 3 items:
bundle-diff-preview (RM-027, wizard impact annotations) and
post-merge-audit-hook (RM-029, post-push audit suggestions) — both spec-only,
no implementation yet.

🔧 The install banner was trimmed from 19 to 12 rows for a less intrusive
first-run experience.

## [1.18.0] - 2026-04-20

✨ `/octopus:pr-open` gained three polish items on top of the earlier redesign. Every section heading now carries an emoji for scanability — `📦 What`, `💡 Why`, `✅ Test plan`, `🔗 References`, `📂 Files changed`. The agent scans branch names, commits, and diffs for roadmap IDs (`RM-NNN`), Jira-style trackers (`[A-Z]{2,}-\d+` with a deny-list for HTTP codes and ISO standards), Notion and GitHub URLs, and local `docs/specs/*.md` / `docs/adr/*.md` paths, surfacing hits in a new conditional `🔗 References` section. The CLI now accepts `--title <string>`; when the agent supplies a human-friendly title prefixed with a type emoji (`🐛 Fix: …`, `✨ Feat: …`, …), it replaces the old branch-derived `feat: foo` title.

🐛 `octopus update` without flags now prefers the latest remote release instead of re-installing whatever is already cached. The previous resolver fell back to `metadata.json` — which records the *currently installed* version, not the update target — so the command silently became a no-op. The new `resolve_update_target()` keeps lockfile pinning as the top priority but skips metadata, going straight to the GitHub API and falling back only to `git describe`. The `"Resolving latest version…"` banner now prints only on the remote path; lockfile resolution says so explicitly.

## [1.17.0] - 2026-04-20

✨ PR descriptions are now written by the agent, not scraped by shell. `/octopus:pr-open` drives the agent to synthesise a three-section body — **What / Why / Test plan** — with the file list collapsed and a fixed `🐙 generated by Octopus` footer. The previous `generate_pr_body` heuristic (which dumped every commit, listed every file, and surfaced nonsense "Key Changes" from regex-matched identifier names) is gone. `cli/lib/pr-open.sh` shrank to ~40 lines of mechanics and now requires `--body-file`.

♻️ Manifest schema correction: in `.octopus.yml`, commit messages and PR descriptions move from `language.docs` to `language.code`. `docs` scope is now restricted to prose artefacts (specs, ADRs, RFCs, README). Field names are unchanged — only the semantic boundary moves. Teams using the short form `language: <code>` are unaffected.

✨ `octopus release commit-changelog` gained a fourth README sync pattern: `--version vX.Y.Z` install examples are now updated automatically alongside the version badge and manual-update snippets.

## [1.16.0] - 2026-04-20

✨ New `/octopus:compress-skill` command — shrinks a `SKILL.md` by ~25% without changing its meaning. A deterministic cleanup pass runs first (collapses blank runs, strips meta prose, shortens example lists); the LLM rewrite pass only fires when the target is not met. Invariants are enforced after each step: frontmatter stays byte-identical, every string the skill's test file greps for is preserved, headings are untouched, and fenced code blocks are copied verbatim. Dry-run is the default; `--apply` writes the result. Registered in the `docs-discipline` bundle and the setup wizard.

♻️ Refactored the three pre-merge audit skills (`money-review`, `tenant-scope-audit`, `cross-stack-contract`) to share conventions via `skills/_shared/audit-output-format.md`. Severity format, override cascade, `--write-report` frontmatter, and common errors now live in one file; each SKILL.md keeps only its skill-specific content. Tests were updated to look for conventions across both the skill file and the shared fragment.

## [1.15.0] - 2026-04-20

✨ The `auto-format` PostToolUse hook gained lint-fix capabilities alongside formatting — TS/JS now runs `biome check --write`, which also organizes imports and applies safe lint fixes, with a fallback to `eslint --fix` + `prettier`. On the .NET side, the hook now prefers **CSharpier** when available and falls back to `dotnet format --include` as before. Formatter failures are surfaced as a single-line message on stderr without blocking the hook. File-extension coverage was expanded to include `mjs`, `cjs`, `jsonc`, and `csx`.

✨ The `release-announce` skill received a Cagan-style refinement covering intent, FBE, and narrative.

## [1.14.5] - 2026-04-20

🎨 Install banner now renders a filled-silhouette octopus in coral (ANSI 210) — round head with two eye holes, geometric smile, two side arms and a fringe of bottom tentacles. 19 rows × 50 cols of `M`-pixel art, every row centered on col 24.5.

## [1.14.4] - 2026-04-20

🎨 Install banner now uses a reddish palette: coral head with bright-yellow eyes and a white smile on top, tentacles fading from dark red to deep red as they curl outward, and a bold-coral `OCTOPUS` title below. Uses 256-color ANSI escapes (terminals that lack 256-color support render the glyphs in the default foreground — still a recognizable octopus).

## [1.14.3] - 2026-04-20

✨ New ASCII-art banner for `install.sh`. The previous design (tiny head + stacked `|` lines as tentacles) read more like a broom than an octopus. Replaced with a recognizable octopus — domed head with eyes and mouth, three curling tentacles on each side — kept in green via the existing color scheme. Rendering switched from seven `echo -e` calls to a `cat <<'BANNER'` heredoc wrapped in `printf '%b'` for the color codes, so the literal art is easier to read and edit in source.

## [1.14.2] - 2026-04-20

🐛 Fixes missing descriptions for 10 slash commands in Claude Code's `/` list: `/octopus:implement`, `/octopus:debugging`, `/octopus:receiving-code-review`, `/octopus:audit-all`, `/octopus:cross-stack-contract`, `/octopus:money-review`, `/octopus:tenant-scope-audit`, `/octopus:plan-backlog-hygiene`, `/octopus:feature-to-market`, `/octopus:release-announce`. The command templates should ship with **two** frontmatter blocks — an outer Octopus metadata block (stripped at delivery) and an inner Claude-readable block (`description:` + `agent:`, preserved). The newer commands were authored with only the outer block, so `strip_frontmatter` removed the entire header and the delivered files had no description for Claude Code to render.

🧪 New `Test 1b` in `tests/test_workflow_commands.sh` asserts every delivered command starts with a frontmatter block containing a `description:` line, preventing this drift on future command additions.

## [1.14.1] - 2026-04-20

🐛 Fixes a silent install regression where `octopus install --latest` and `octopus update --latest` would stamp the new version's name over the current `RELEASE_ROOT` via a symlink — so `~/.octopus-cli/cache/v1.14.0` could end up pointing to a v1.8.0 tree, and `octopus setup` would silently deliver the old command/skill set. The shim's `install_release` now detects the mismatch: when `RELEASE_ROOT`'s git tag doesn't match the requested version, it delegates to `install.sh` (either the one bundled in the release tree or a fresh copy fetched from GitHub) with a new `--no-shim-setup` flag that runs the download/extract path without touching the running shim. Self-install bootstrap (the dev-checkout case where `RELEASE_ROOT == target`) still works as before.

🧪 New `tests/test_install_release.sh` covers both paths: (a) when the requested version can't be fetched, no bogus symlink is left behind; (b) the self-install bootstrap still succeeds and writes metadata.

**Upgrade note:** users whose cache contains symlinked version dirs (e.g. `v1.14.0 -> v1.8.0`) should delete the broken entry and reinstall: `rm ~/.octopus-cli/cache/v1.14.0 && curl -fsSL https://github.com/leocosta/octopus/releases/latest/download/install.sh | bash -s -- --version v1.14.0 --force`. Once on v1.14.1, the bug can't recur.

## [1.14.0] - 2026-04-20

🧭 Task routing matrix (RM-034) lands as a canonical markdown fragment at `skills/_shared/task-routing.md`, embedded byte-identically in the three starter workflow skills (`implement`, `debugging`, `receiving-code-review`). Four signal categories — Stack/language (paths, stack traces), Domain-audit (billing keywords, multi-tenant queries, cross-stack diffs, secrets), Cross-workflow (feature vs. bug vs. review handoffs), Risk-profile (large-scale change, migration, release) — map observable task signals to the companion skills worth consulting. Graceful degradation: when a companion skill isn't installed, the main workflow continues and surfaces a one-line hint rather than blocking.

🔄 Replaces the RM-034 stub paragraph in all three skills; the `## Task Routing` heading stays in place, so the section-level structural tests are unaffected. Per-skill tests (`test_implement.sh`, `test_debugging.sh`, `test_receiving_code_review.sh`) now check for the `<!-- BEGIN task-routing -->` marker instead of the `RM-034` placeholder string.

🧪 New `tests/test_task_routing.sh` enforces byte-identical sync between the canonical fragment and the three SKILL.md embeds via `awk` block extraction and `diff`, so any future drift fails CI with a 20-line diff preview. `skills/_shared/` is deliberately outside the `skills/*/SKILL.md` discovery glob, so the fragment is an authoring-only artifact — never delivered as a skill.

## [1.13.0] - 2026-04-20

🔒 New destructive-action guard hook intercepts dangerous Bash commands before the agent runs them. `hooks/pre-tool-use/destructive-guard.sh` is a PreToolUse/Bash hook that matches a curated blocklist (`rm -rf`, `git push --force`, `git reset --hard`, `git checkout --`, `git clean -f`, `DROP TABLE`, `DROP DATABASE`, `TRUNCATE`, `DELETE FROM` without `WHERE`, `chmod -R 777`, `find ... -delete`, `npm uninstall -g`, `curl | bash`) and blocks with exit code 2 plus a stderr message that explains the rule and how to bypass. The bypass is a `# destructive-guard-ok: <reason>` marker in the command text itself — the reason must be non-empty and surfaces in command history and code review, so the override is visible rather than silent. A legitimate `DELETE FROM t WHERE expired < now();` is not blocked; the guard only trips when the WHERE clause is absent.

🔧 Integration with the existing Octopus hooks pipeline: the script ships in `hooks/pre-tool-use/`, registers in `hooks/hooks.json` under `PreToolUse`/`Bash`, and is delivered automatically by the installer's `deliver_hooks` when `hooks: true` is set in `.octopus.yml` (the default for the `quality-gates` bundle and common in `starter`). Opt-out via a new manifest field `destructiveGuard: false`, which routes through the existing `OCTOPUS_DISABLED_HOOKS` filter so the hook is absent from the rendered `settings.json` without disabling the rest of the hooks layer. Claude Code sees exit code 2 as "block this tool call and surface the message to the model", so the agent gets the block reason and can retry with a justified marker.

🐛 Also fixes a pre-existing bug in the `deliver_hooks` python filter: the previous code compared `id` at the matcher-entry level when `id` actually lives one level deeper (inside each entry's `hooks` array). The filter never removed anything. Now filters at both levels and drops matcher entries whose `hooks` array becomes empty. The `OCTOPUS_DISABLED_HOOKS` env var therefore works as documented for the first time.

📝 Ships with tutorial at `docs/features/destructive-action-guard.md`, new row in `docs/features/hooks.md`, `destructiveGuard:` entry added to the README `.octopus.yml` snippet, roadmap transition (RM-033 moves to Completed), and a 7-test structural suite covering script existence + executability, 14 destructive patterns each blocked, 5 safe commands each pass, non-Bash payloads exit 0, exit code 2 on blocks, hooks.json registration, and the injection + opt-out behavior through the full `deliver_hooks` path.

## [1.12.0] - 2026-04-19

✨ New `receiving-code-review` skill codifies the PR-feedback discipline — verify the critique against the code, ask for evidence on generic comments, separate reasoned feedback from preference, never make performative changes, ask for clarification on ambiguity. Active by default on every PR feedback loop, the skill joins the `starter` foundation bundle as the third workflow skill alongside `implement` (features) and `debugging` (bugs). The starter bundle now covers the three common working states: writing new code, fixing broken code, responding to feedback on code. Rule 1 requires reading the code the reviewer pointed at before accepting the critique — a reviewer who is wrong wants to know, not to be agreed with. Rule 2 refuses to infer the intent of generic comments ("this is ugly") — ask for specificity. Rule 3 separates technical reasoning from personal preference and negotiates preference honestly rather than treating it as an instruction. Rule 4 forbids changing code just to close a thread without understanding the concern. Rule 5 asks for clarification when a comment allows multiple readings.

🎨 Stack-neutral by design. The skill describes discipline, not a specific review tool or platform. When the `superpowers:*` plugin is installed, `superpowers:receiving-code-review` wins per rule on the practices it already covers; this skill still owns Octopus-native integration with `/octopus:pr-comments` and the handoffs to `implement` and `debugging`. Section `## Task Routing` reserves the same extension hook RM-034 will wire into all three starter-workflow skills.

📝 Ships with tutorial at `docs/features/receiving-code-review.md`, wizard registration, README + skills.md updates, roadmap transition (RM-032 moves to Completed), and 9 structural tests. `tests/test_bundles.sh` bumps to reflect the starter bundle growing to 6 skills (Test 5) and the full bundle expansion reaching 11 skills (Test 9).

## [1.11.0] - 2026-04-19

✨ New `debugging` skill codifies the universal bug-fix workflow — reproduce deterministically, isolate, fix with a regression test first, document non-obvious cause. Active by default on every bug-triage task, the skill joins the `starter` foundation bundle alongside `implement`, so every repo running `octopus setup` now has symmetric coverage: `implement` for features, `debugging` for bugs. The body documents four phases in a fixed order. Phase 1 requires a deterministic reproduction before proposing a cause — "works on my machine" and "sometimes happens" are symptoms of missing context. Phase 2 isolates via `git bisect` (for regressions) or hypothesis → test → refute (for everything else); logs confirm hypotheses but do not substitute for isolation. Phase 3 writes the failing regression test before the fix, reusing `implement`'s TDD loop with the red step sourced from the bug. Phase 4 documents non-obvious causes in the commit message, an ADR, or a `continuous-learning` entry, so the same bug does not recur under a different symptom months later.

🎨 Stack-neutral by design. The skill describes a protocol, not specific debuggers or languages. When the `superpowers:*` plugin is installed, `superpowers:systematic-debugging` wins per phase on the practices it already covers; `debugging` still owns Phase 4 (Octopus-native integration with `continuous-learning` and ADRs). Section `## Task Routing` reserves the same extension hook RM-034 will wire into `implement`, so both skills share one routing edit when RM-034 lands.

📝 Ships with tutorial at `docs/features/debugging.md`, wizard registration, README + skills.md updates, roadmap transition (RM-031 moves to Completed), and 9 structural tests covering frontmatter, all six required sections, the four phase headers, Task Routing mentioning RM-034, Anti-Patterns naming core violations, slash command, bundle membership, wizard wiring, and tutorial presence. `tests/test_bundles.sh` bumps to reflect the starter bundle growing to 5 skills (Test 5 fixture) and the full bundle expansion reaching 10 skills (Test 9).

## [1.10.0] - 2026-04-19

✨ New `implement` skill codifies the universal implementation workflow. Active by default on every code-editing task — the skill joins the `starter` foundation bundle so every repo running `octopus setup` picks it up automatically. The body documents five practices in a fixed order: (1) TDD loop (red → green → refactor → commit for observable behavior); (2) plan-before-code gate (present a short plan on tasks touching > 2 files or with ambiguous approach); (3) verification-before-completion (run the project's test/typecheck/format and attach output before declaring work done); (4) simplify pass (re-read changed code with the simplifier lens before committing); (5) commit cadence (one commit per logical step, hooks must pass, never `--no-verify`).

🎨 Stack-neutral by design. The skill does not duplicate `rules/common/*` (static rules) or compete with language-specific skills (`dotnet`, `backend-patterns`, `e2e-testing`). When the user has the `superpowers:*` plugin installed, composition rule is "the more specific skill wins per practice" — superpowers drives TDD / systematic debugging / verification when active; `implement` fills the other gaps. Section `## Task Routing` reserves an extension hook for RM-034, which will auto-dispatch to the right sub-skill or role per task (backend / frontend / infra / data / refactor / bug).

📝 Ships with tutorial at `docs/features/implement.md`, wizard registration, README + skills.md updates, roadmap transition (RM-030 moves to Completed), and 9 structural tests covering frontmatter, all six required sections, the five practice headers, Task Routing mentioning RM-034, Anti-Patterns naming core violations, slash command, bundle membership, wizard wiring, and tutorial presence.

## [1.9.0] - 2026-04-19

✨ New `audit-all` composer skill runs `security-scan`, `money-review`, `tenant-scope-audit`, and `cross-stack-contract` in parallel against one ref with shared file discovery and a consolidated severity report. Instead of four sequential invocations (each duplicating ref resolution, diff computation, file classification), `audit-all` does the discovery work once, partitions touched files by domain (money / tenant / webhook / auth / api-contract / frontend-consumer / secrets / config), dispatches four subagents via `superpowers:dispatching-parallel-agents`, then merges the four reports into one output with a **cross-audit hotspots table** — files flagged by ≥ 2 audits surface at the top for triage. Every sub-report keeps its own `🚫/⚠/ℹ + confidence` footer so reviewers can paste an audit's section into a PR thread.

🔧 New `depends_on:` skill-frontmatter mechanism. A skill can declare `depends_on: [skill-a, skill-b]` in its frontmatter; `expand_bundles()` walks the list after bundle expansion, pulls each dependency, loops until stable, warns on missing deps, aborts on cycles or excessive depth (5 passes). This lets `audit-all` declare its four audit dependencies in one place — `bundles/quality-gates.yml` now lists only `audit-all`, the four individual audits arrive automatically. Individual audits remain first-class and invocable directly via `/octopus:security-scan`, `/octopus:money-review`, etc.

🎨 Graceful degradation: `audit-all` adapts to what's installed. A missing dependency skips that audit with a warning; the summary line reports "{N} of 4 audits ran; install {list} to enable the rest". When `superpowers:dispatching-parallel-agents` is unavailable (non-Claude-Code agents), execution falls back to sequential with a one-line notice; output shape is identical. v1 always exits 0 (guidance, not gate).

📝 Ships with tutorial at `docs/features/audit-all.md`, updates to README / skills.md / bundles.md tables, closes RM-028 in the roadmap. 13 structural tests (7 for the skill itself + 4 new `depends_on` scenarios in `test_bundles.sh` covering happy path, missing-dep warning, cycle detection, no-deps skills).

## [1.8.2] - 2026-04-19

📝 Every slash-command tutorial heading now shows the fully-qualified `/octopus:<name>` form. Before, the level-1 heading in `commands/*.md` rendered as `# /<name>`, which made the `octopus:` namespace look like a typo to new users who saw only the tutorial. Fixed across all 10 user-invoked commands: `cross-stack-contract`, `doc-adr`, `doc-research`, `doc-rfc`, `doc-spec`, `feature-to-market`, `money-review`, `plan-backlog-hygiene`, `release-announce`, `tenant-scope-audit`.

🐛 `docs/features/bundles.md` also gains `release-announce` in the `growth` bundle row — v1.8.0 added the skill to the bundle YAML but the tutorial table missed it, so readers browsing the bundle catalog thought `growth` still shipped only `feature-to-market`.

## [1.8.1] - 2026-04-19

🐛 `install.sh` reused any existing `cache/v<version>/` directory without verifying its contents — so a dir created by an aborted download, a manually-copied staging snapshot, or an older installer that packaged stale content under a newer label would be silently reused. Result: the `current` symlink pointed at a directory labeled `v1.8.0` that actually shipped v1.5.0 code, leading to `octopus setup` regenerating `.claude/settings.json` with the pre-v1.5.1 bugs (relative hook paths, invalid `PostToolUseFailure` event, unsupported top-level keys). Fix: on successful extraction the installer now writes the verified tarball SHA256 to `<cache-dir>/.cache-sha256` as an integrity marker. On subsequent runs, when the cache dir exists, the installer fetches the release's checksum file and compares it against the marker; mismatch or missing marker triggers a fresh re-extract, while a match reuses the cache. When no checksum endpoint is available (offline install or custom mirror), the installer falls back to the legacy "dir exists → reuse" behavior so offline flows keep working. `--force` continues to unconditionally re-download.

🧪 `tests/test_installer.sh` gains four assertions covering the full contract: marker is written after a fresh extract, a corrupted cache is purged and re-extracted on the next run (detected via a canary file that survives only if the dir was NOT wiped), a healthy cache is reused without redundant download, and `--force` always re-downloads even when the cache is healthy.

## [1.8.0] - 2026-04-19

✨ New `release-announce` skill turns one or more refs (tags, tag ranges, RM IDs) into a themed release announcement kit aimed at **existing users** — a distinct job from `feature-to-market`, which handles acquisition and external audiences. Inputs can be a single version (`v1.7.0`), a range (`v1.5.0..v1.7.0`), or an RM ID (`RM-008`); default is since the last tagged release. Output is two-tiered: **canonical artifacts** (`index.html` themed landing page, `notes.md` plain fallback, `theme.yml` snapshot for reproducibility) plus **paste-ready channel messages** under `channels/` for email, Slack, Discord, in-app banner, status page, X/Twitter thread, WhatsApp, and an autocontained slide deck with keyboard nav and print-to-PDF.

🎨 Nine preset themes ship in v1 — `classic` (neutral newsletter default), `jade` (calm green), `dark` (modern high-contrast), `bold` (vibrant with oversized display), `newsletter` (text-heavy serif), `sunset` (warm orange/pink), `ocean` (cool blues), `terminal` (green mono-on-black dev aesthetic), and `paper` (editorial cream/browns). Each theme is a YAML file declaring palette, typography, layout (hero / grouping / density), and voice (tone / persona) tokens. Users pick via `.octopus.yml theme:` or per-run `--theme=<name>`. `--channels=<list>` controls the channel subset; default `email,slack,in-app-banner`. `--audience=<user|developer|executive>` tunes copy voice.

🔧 `--design-from="<prompt>"` optionally invokes the `frontend-design` skill to synthesize a custom theme YAML on the fly (e.g. `--design-from="retro arcade synthwave"`). The generated theme is persisted to `docs/release-announce/themes/<slug>.yml` and reusable via `--theme=<slug>` in subsequent runs. Default path stays deterministic — `frontend-design` is invoked only via `--design-from`, never for plain rendering.

📝 Slides template ships with ≤40 lines of vanilla JS (keyboard `→`/`←`/`Space`/`PageUp`/`PageDown`, touch swipe, URL hash persistence, print-to-PDF via `@page` landscape), inline CSS, no external assets. Email template uses bulletproof patterns (inline CSS, `<table>` layout, no `<script>`/`<style>` in body). The skill joins the `growth` bundle next to `feature-to-market`, covers acquisition + retention in one bundle. 12 structural tests guard skill content, theme shape, template tokens, slides JS budget, and wizard / bundle / README / skills.md integration.

## [1.7.0] - 2026-04-19

✨ Introduces **bundles** as the primary setup path. The wizard's Quick mode (default) now asks 4–6 yes/no persona questions ("Is this a SaaS product for external customers?", "Does your team produce marketing content?", "Primary backend is .NET?") and maps each positive answer to a curated bundle of skills + roles + rules. Seven bundles ship in v1: `starter` (foundation — `adr`, `feature-lifecycle`, `context-budget`; always included), four intent bundles (`quality-gates` → security-scan + money-review + tenant-scope-audit + backend-specialist role; `growth` → feature-to-market + social-media role; `docs-discipline` → plan-backlog-hygiene + continuous-learning + tech-writer role; `cross-stack` → cross-stack-contract + backend + frontend specialists), and two stack bundles (`dotnet-api`, `node-api`). Users can declare `bundles: [...]` in `.octopus.yml` and the expansion happens at setup time — a new user never needs to memorize the 13-skill catalog to get a sensible config. Power users still pick Full mode or mix explicit `skills:` / `roles:` on top of bundles; all user-explicit entries are additive (bundles never remove selections).

🔧 Implementation: new `OCTOPUS_BUNDLES` array parsed by `parse_octopus_yml`, `_load_bundle` reads a single YAML via python3, `expand_bundles` unions components across bundles with `_dedupe_array` preserving first-seen order. The expansion runs before any delivery function, so `deliver_skills` / `deliver_roles` / `deliver_mcp` stay oblivious to bundles — the feature is purely a preprocessing layer. New `_wizard_sub_bundles()` reads each bundle's `persona_question` and asks y/n; the Quick-mode flow now takes three grouped steps (Agents → Bundles → Workflow) instead of a one-shot 3-question form. The manifest writer emits `bundles:` when the wizard picked any, and skips emitting expanded `skills:` / `roles:` lists in that case.

📝 Docs: new `docs/features/bundles.md` tutorial covers Enable / Combining / Authoring / the new-skill convention. `docs/features/skills.md` gains a Bundle column showing membership for every skill. README intro, Quick Start, and Features table all surface bundles as the primary path. `templates/spec.md` gains a required `Bundle:` field in the "Context for Agents" section, enforcing the convention that every future skill declares bundle membership in its spec — no loose skills drift into the catalog without users discovering them.

🧪 New `tests/test_bundles.sh` runs nine assertions: bundle metadata presence, persona-question coverage for intent/stack, parser recognizes `bundles:`, loader populates component arrays, unknown bundle aborts loudly, union across multiple bundles, de-duplication of overlapping contributions, preservation of user-explicit entries, and full manifest round-trip (bundles-only YAML expands to the expected 6 skills + roles).

## [1.6.0] - 2026-04-19

✨ New `tenant-scope-audit` skill catches the systemic data-leak risk in multi-tenant SaaS codebases: a query without a tenant filter returns rows from every tenant. Given a branch or PR, the skill resolves the diff against a base, reads the optional `.octopus.yml` `tenantScope:` config (fields `field` / `filter` / `context` / `entities`, with defaults `TenantId` / `AppQueryFilter` / `AppDbContext`), identifies tenant-relevant files via path tokens (`Controller`, `Service`, `DbContext`, `Queries`, …) and content heuristics, and runs six inspection checks. T1 (`query-without-filter`) blocks on `IgnoreQueryFilters()` calls without a preceding `// tenant-override: <reason>` marker; T2 (`dbcontext-missing-filter`) blocks on new `DbSet<X>` entries lacking `HasQueryFilter` configuration; T3 (`raw-sql-no-filter`) blocks on `FromSqlRaw` / `ExecuteSqlRaw` / `Database.SqlQuery` whose SQL literal does not restrict by the tenant field. T4 (`id-from-route-no-ownership`) warns when a controller action accepts an id from the route and calls `.FindAsync(id)` on a tenant-scoped DbSet without a known ownership helper; T5 (`join-to-unfiltered-table`) warns on LINQ joins into a global table without tenant restriction; T6 (`cross-tenant-admin-endpoint`) warns on `[AllowAnonymous]` / `[Authorize(Roles = "Admin")]` methods that touch tenant-scoped data without a `// across-tenants: <reason>` marker.

🎨 Every finding carries a `confidence` label (`high` / `medium` / `low`) for triage parity with `cross-stack-contract`. The report format matches the existing `money-review` / `cross-stack-contract` / `security-scan` output (`🚫 Block / ⚠ Warn / ℹ Info`) plus a one-line config trailer showing which tenant field / filter / context were in effect. `--write-report` persists to `docs/reviews/YYYY-MM-DD-tenant-<slug>.md`; `--only=<checks>` runs a subset; `--base=<branch>` overrides the default `main`.

📝 Ships with default regex tokens for EF raw-SQL helpers, admin role markers, and override-marker comment grammar. Override cascade at `docs/tenant-scope-audit/patterns.md`. Tutorial at `docs/features/tenant-scope-audit.md` documents the `tenant-override:` and `across-tenants:` comment contracts. 8 structural tests, wizard + README + `skills.md` descriptions-table row integration. All four audit skills (`security-scan`, `money-review`, `cross-stack-contract`, `tenant-scope-audit`) now share one output format, so a combined PR comment concatenates without extra formatting.

## [1.5.1] - 2026-04-19

🐛 Three bugs in `.claude/settings.json` generation that could prevent Claude Code from loading the file. First, hook commands were emitted as relative paths (`octopus/hooks/pre-tool-use/block-no-verify.sh`) that do not resolve from the project's working directory — Claude Code would try to run a non-existent script. `deliver_hooks` in `setup.sh` now rewrites the `octopus/hooks/` prefix to the absolute Octopus install root (`$OCTOPUS_DIR/hooks/`), so every hook command is an absolute path that executes regardless of CWD. Second, `hooks/hooks.json` shipped a `PostToolUseFailure` event that is not part of Claude Code's documented hook schema; its presence could invalidate the settings.json on strict validation. The event and its companion `mcp-health` hook are removed. Third, `deliver_boris_settings` wrote experimental keys (`worktree`, `autoMemory`, `autoDream`, `sandbox`) at the top of settings.json plus `permissionMode: "auto"`, none of which are accepted values in Claude Code's schema. The function now whitelists only the schema-documented keys (`permissionMode`, `outputStyle`) and normalizes `permissionMode=auto` to `default`. The related features still ship (the dream subagent is delivered as a Claude agent file, the batch skill is an independent skill, etc.) — they just do not pollute `settings.json` with unrecognized keys.

🧪 New `tests/test_hooks_injection.sh` guards the three invariants: every hook command starts with `/`, no invalid events land in `settings.json`, and Boris-tip passthroughs are filtered + normalized correctly.

## [1.5.0] - 2026-04-19

✨ New `plan-backlog-hygiene` skill keeps the planning surface honest over time. Repos that lean on the feature-lifecycle accumulate plans, specs, and research docs faster than teams archive them — Tatame's `plans/` has grown past 50 files. The skill walks the planning directory (autodetected as `plans/`, `docs/plans/`, or `docs/superpowers/plans/`, or overridden via the new `.octopus.yml` `plansDir:` field), parses `docs/roadmap.md`, and cross-references the two. Six hygiene checks land in v1: orphan plans with no RM/PR/issue/spec reference (H1, Info), plans for already-completed RMs still sitting outside `archive/` (H2, Warn — auto-fixable), duplicate plans for the same RM-NNN (H3, Warn), broken internal links to missing specs/research/ADRs (H4, Warn), roadmap RMs in progress without a matching plan file (H5, Info), and plans unchanged longer than `--stale-days` (H6, Info, default 90).

🔧 `--fix` applies a single reversible action: for H2 matches, move the plan to `<plansDir>/archive/YYYY-MM/<filename>` using `git mv` so history is preserved. The move is staged but not committed, so `git restore --staged` undoes cleanly. A clean working tree is required. Other checks are never auto-fixed — H1/H3/H4/H5/H6 all need human judgment. `--write-report` persists the report to `docs/reviews/YYYY-MM-DD-hygiene.md`; `--only=<checks>` runs a subset; `--stale-days=<n>` tunes H6.

📝 Output format matches `money-review` and `cross-stack-contract` so a monthly "hygiene digest" PR can concatenate all three reports into one comment. Ships with default regex for RM/PR/issue/internal-link detection, roadmap status parsing (recognizes `completed`, `in progress`, `proposed`, `blocked`), an archive convention, tutorial at `docs/features/plan-backlog-hygiene.md`, 8 structural tests, and wizard + README integration. Pairs naturally with the `schedule` skill for monthly cron runs.

## [1.4.0] - 2026-04-19

✨ New `cross-stack-contract` skill detects API-vs-frontend contract drift in multi-stack monorepos — the silent bugs that only surface at integration runtime when a DTO field renamed on the .NET side is never updated on the React or Astro twin. Given a branch or PR, the skill partitions the diff by stack (via `.octopus.yml` `stacks:` map or autodetection over `api/`, `apps/api/`, `backend/`, `server/` for the API and conventional paths for React/Vue/Angular and Astro/Next landing pages), extracts contract intent tokens from the API diff (endpoint paths, DTO/record names, enum names, route attributes, auth annotations, param lists), and grep-matches them against frontend usage. Seven drift classes land in v1: endpoint additions without a consumer (C1, Info), endpoint removals/renames still called by a frontend (C2, Block), DTO field drift (C3, Warn), enum member desync (C4, Warn), response status code changes (C5, Info), authorization rule changes (C6, Warn always), and path/query param shifts that break live call sites (C7, Warn).

🎨 Every finding carries a **confidence** label (`high`/`medium`/`low`) so reviewers can triage heuristic matches quickly. The output format is the same three-heading severity markdown emitted by `money-review` and `security-scan`, so three audits can be concatenated into a single PR comment without extra formatting work. `--write-report` persists the report to `docs/reviews/YYYY-MM-DD-contract-<slug>.md` with frontmatter listing the stacks compared and the summary counts. `--stacks=<list>` restricts the comparison; `--only=<checks>` runs a subset of C1–C7.

📝 Ships with default endpoint/DTO/consumer patterns for .NET (ASP.NET Controllers, Minimal API), Node (Express, Fastify, Hono, NestJS, Astro file routes), React / Vue / Angular / Astro frontends, and frontend consumer idioms (fetch/axios/ky, React Query/SWR, generated SDKs). Override cascade at `docs/cross-stack-contract/patterns.md`. Tutorial at `docs/features/cross-stack-contract.md`, 8 structural tests, wizard + README integration.

## [1.3.0] - 2026-04-19

✨ New `money-review` skill audits money-touching code before merge. It resolves a branch or PR against a base, isolates money-touched files via filename and regex heuristics (tokens like `billing`, `payment`, `split`, `asaas`, `pix`, `webhook`, `fee`), and runs seven inspection families: numeric type safety (T1 — flag `float`/`double`/`number` for currency), explicit rounding strategy (T2), cents coverage in tests (T3 — require non-round literals like `0.01`, `199.99`), env-var consistency across sandbox and production (T4 — block when a new `*_PERCENT`/`*_FEE`/`*_RATE` exists in one environment but not the other), payment-call idempotency (T5 — flag POST calls lacking `Idempotency-Key` or `externalReference`), webhook signature verification (T6 — block new `/webhook` endpoints without a verifier helper), and fee/tax disclosure coupling (T7 — warn when a fee change lands without a spec mentioning disclosure).

🎨 Output is a severity-tiered markdown report (`🚫 Block / ⚠ Warn / ℹ Info`) designed to paste into a PR comment as-is. With `--write-report`, the same content is persisted to `docs/reviews/YYYY-MM-DD-money-<slug>.md` with frontmatter for traceability. The `--only=<families>` flag restricts the scan to a subset; `--base=<branch>` overrides the default `main`.

📝 Ships with embedded default patterns (`skills/money-review/templates/patterns.md`), provider idioms for Asaas / Stripe / Mercado Pago (`templates/providers.md`), a three-level override cascade (`docs/money-review/patterns.md` → `docs/MONEY_REVIEW_PATTERNS.md` → embedded), a tutorial at `docs/features/money-review.md`, and 8 structural tests guarding skill / command / wizard integration. Composes with the existing `security-scan` skill — run both on any billing PR.

## [1.2.0] - 2026-04-19

✨ New `feature-to-market` skill turns a completed feature (RM-NNN, spec path, research path, or PR) into a versioned multi-channel launch kit under `docs/marketing/launches/YYYY-MM-DD-<slug>/`. The kit bundles Instagram, LinkedIn and X posts, a launch email, landing-page copy, a commercial changelog entry, and a 30–60s video script — each rendered from per-channel templates with placeholders populated from the resolved feature context. Invocation is a single slash command (`/octopus:feature-to-market <ref>`) with flags for channel selection, dry-run, forced angle, and regeneration. Brand and voice pull from a three-level override cascade: `docs/marketing/<name>.md` (canonical) → `docs/<NAME>.md` (uppercase compat with repos that already keep these files at the docs root) → embedded defaults shipped with the skill.

🎨 Optional image generation stays free by default: `GEMINI_API_KEY` (free tier at aistudio.google.com) is the preferred provider, with Pollinations.ai as a zero-setup fallback and graceful degradation to prompts-only when neither is available. Brand palette and logo constraints from `brand.md` are injected into every prompt; aspect ratios are pre-tuned per channel (1:1 IG, 1.91:1 LI, 16:9 X card, 16:9 LP hero).

📝 Tutorial lands at `docs/features/feature-to-market.md`, README skills list and the setup wizard (`cli/lib/setup-wizard.sh`) gain the new entry, and 13 structural tests guard file layout, frontmatter, documented sections, and wizard registration.

## [1.1.1] - 2026-04-18

🔧 Cleanup delivery closing RM-019, RM-020 and RM-021. `install.sh` no longer embeds a HEREDOC copy of the `bin/octopus` shim — the installer now copies the shim straight from the extracted release tree, removing 307 lines and eliminating the drift risk between the two sources. The release pipeline in `.github/workflows/build-release.yml` signs the published tarball with GPG and uploads `octopus-<tag>.tar.gz.asc` alongside the existing `.sha256`, closing the loop on RM-009's consumer-side verification (requires `OCTOPUS_RELEASE_GPG_KEY` and `OCTOPUS_RELEASE_GPG_PASSPHRASE` to be provisioned as repo secrets — see `docs/specs/release-signing-pipeline.md`).

🧪 Four tests that had been waved through as "pre-existing failures" since before v1.0.0 are now fixed. They referenced functions renamed during earlier refactors (`generate_claude`, `inject_mcp_servers`), missed a pipeline step (`collect_gitignore_entries`), or used assertions that the current delivery contract outgrew. The full test suite now reports **19/19 green** on a clean checkout.

## [1.1.0] - 2026-04-18

Consolidated delivery of RM-011 through RM-018.

✨ Seven new manifest fields expose Boris Cherny's Claude Code tips as first-class Octopus configuration. `worktree`, `memory`, `dream`, `sandbox` and `permissionMode`/`outputStyle` flow through to `.claude/settings.json` as passthroughs. `githubAction: true` idempotently scaffolds `.github/workflows/claude.yml` for automated PR review. The new `batch` skill documents a fan-out pattern for applying the same prompt across many targets in isolated git worktrees, and a `dream` subagent (Haiku, Read/Write only) ships to consolidate and prune stale memory entries.

✨ Install scopes land as RM-018. A new `--scope=repo|user` flag (plus `OCTOPUS_SCOPE` env var, `scope:` manifest field, and a wizard pre-flight question) lets teams install a shared base configuration at `~/.claude/` and layer per-repo overrides on top — every agent already merges user-level with project-level config at read time. User-scope manifests live at `~/.config/octopus/.octopus.yml` following XDG; secrets go to `~/.config/octopus/.env.octopus` with `chmod 600`. Fields that don't make sense at user scope (`mcp`, `workflow`, `reviewers`, `githubAction`, `knowledge`) warn and are ignored; `.gitignore` updates and CI scaffolds are skipped.

🎨 The setup wizard was reorganized from 12 sequential steps into 5 grouped steps (Basics, What the AI knows and does, Integrations, Team workflow, Advanced Claude settings) with sub-question headers inside each group. A new pre-flight Quick/Full mode lets users opt for a 3-question fast path or walk the full flow. Reconfigure mode suppresses long descriptions and hints unless `OCTOPUS_WIZARD_VERBOSE=1`. The Advanced step is skipped entirely when Claude is not in the agent list.

📝 Eight new specs document the delivery: worktree-isolation, auto-mode, memory-dream, sandbox, output-styles, github-action, batch-skill, install-scopes. Roadmap reconciled with RM-011 through RM-018 in Completed.

## [1.0.0] - 2026-04-18

Marks the first stable release, consolidating RM-005 through RM-009 in a single delivery.

✨ The global CLI installer now verifies detached GPG signatures alongside the existing SHA256 check — configurable via `OCTOPUS_GPG_KEYRING`, `OCTOPUS_GPG_IMPORT_KEY`, `OCTOPUS_REQUIRE_SIGNATURE`, and `OCTOPUS_SKIP_SIGNATURE`, closing the remaining supply-chain gap on compromised mirrors. Installer hardening continues with new `--bin-dir` / `--cache-root` flags, `OCTOPUS_INSTALL_ENDPOINT` support for `file://` mirrors, and real SHA256 capture in `metadata.json`.

✨ Setup UX was unified across `install.sh`, the interactive wizard, and `setup.sh`. A new `cli/lib/ui.sh` module provides shared vocabulary that groups per-agent delivery under a single step line. Every wizard prompt now dispatches to the active TUI backend (fzf / whiptail / dialog / bash), and each of the eleven wizard steps gained a contextual explanation plus per-item hints.

📝 Role templates can now declare a `tools:` frontmatter field that is preserved for Claude Code and stripped for every other target. Language rules specs were promoted to Implemented alongside the behavioral detection rule and the project-override mechanism.

⚠️ BREAKING CHANGE: submodule mode is no longer supported. `cli/lib/update.sh`, `commands/update.md`, `tests/test_update.sh`, the submodule branch in `setup.sh` PROJECT_ROOT resolution, `OCTOPUS_CLI_REL`, and every submodule/legacy-shim reference across README, commands, and feature docs were removed. Existing submodule installs must switch to the global CLI (`install.sh`) and re-run `octopus setup`; the manifest is preserved. RM-010 (`octopus migrate` helper) was rejected as a consequence.

## [0.16.1] - 2026-04-06
Fixed a syntax error in the _select_one bash fallback function that was causing issues in the setup process. 🐛

## [0.16.0] - 2026-04-06
Added an interactive TUI setup wizard (`octopus setup`) that guides users through configuring `.octopus.yml` with multi-backend support (fzf/whiptail/dialog/bash) and full Windows/Git Bash compatibility. ✨

## [0.15.10] - 2026-04-05
Fixed the CLI setup for PROJECT_ROOT and added interactive scaffolding features. 🐛

## [0.15.9] - 2026-04-05
Fixed the CLI setup command by adding the missing setup command to cli/octopus.sh 🐛

## [0.15.8] - 2026-04-05
Added contents: write permission for GitHub release upload in CI workflow. 🐛

## [0.15.7] - 2026-04-05
Fixed a CI issue where the tar archive was causing self-modification errors by writing it to /tmp instead. 🐛

## [0.15.6] - 2026-04-05
🐛 Replaced softprops action with gh CLI and upgraded checkout to v6 in CI workflows.

## [0.15.5] - 2026-04-05
🔁 Set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` on the release job so all JavaScript actions (including `actions/checkout@v4`) run under Node.js 24. The `v4.x` line bundles Node.js 20 internally regardless of the pinned version tag, causing a deprecation warning that surfaced as a runtime failure on the updated GitHub runners.