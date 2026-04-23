# Research: Octopus Control — Gap Analysis

- **Date:** 2026-04-23
- **Slug:** octopus-control-gaps
- **Trigger:** User experience friction after first real usage of `octopus control`

---

## Context

`octopus control` (RM-044) shipped in v1.23.0 as a TUI dashboard for local multi-agent
orchestration. This session analyses gaps found during first real use, combining user
feedback with a code-level inspection of `cli/control/`.

### Primary pain points (user-reported)

- No skill autocomplete in the command bar — user doesn't know what skills exist
- No real-time feedback that the agent is actually running
- Difficulty stopping an agent reliably

### Code inspection findings

Reading `app.py`, `process_manager.py`, `queue.py`, `scheduler.py`, and
`skill_matcher.py` revealed several features that are defined but not wired up:

| Finding | Location |
|---|---|
| `Scheduler` class never instantiated in `app.py` | `scheduler.py` / `app.py:on_mount` |
| `worktrees_dir` created but unused; agents run on shared `cwd` | `process_manager.py:__init__` |
| Log output is a single `Label` (last line only) | `app.py:_stream_log` |
| `needs_confirm` / `ambiguous` from `SkillMatcher` never surfaced in UI | `app.py:on_input_submitted` |
| `TaskQueue.dequeue()` exists but never called; done tasks accumulate | `queue.py` / `app.py` |
| Exit code not captured; dead agents always → `done`, never `failed` | `app.py:_reap_dead_agents` |
| No log viewer for completed tasks | `app.py` — no task-select handler |

---

## Validated Roadmap Items

| ID | Title | Priority | Effort |
|---|---|---|---|
| RM-045 | Typeahead autocomplete for skills in command bar | 🔴 High | medium |
| RM-046 | Real-time scrollable log panel (RichLog) | 🔴 High | medium |
| RM-047 | Animated status indicator in agent roster | 🔴 High | low |
| RM-048 | Wire Scheduler into app — dispatch scheduled tasks | 🔴 High | low |
| RM-049 | Task `failed` state via exit code capture | 🟡 Medium | low |
| RM-050 | Log viewer for completed tasks | 🟡 Medium | low |
| RM-051 | Queue cleanup — auto-dequeue done/failed tasks | 🟡 Medium | trivial |
| RM-052 | Worktree isolation per agent | 🟢 Low | high |

---

## Discarded / Deferred

_None discarded. RM-052 (worktree isolation) is marked Low priority because agents
editing different files in the same cwd rarely conflict in practice; can be revisited
once the higher-priority UX items are stable._
