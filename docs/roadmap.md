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

### Cluster 6 — Local agent orchestration

_RM-044 complete. Cluster 6 has no open items._

`octopus control` shipped in v1.23.0. All UX gaps (RM-045..052) closed in PR #92.

### Cluster 7 — End-to-end pipeline runner

_RM-053 complete. Cluster 7 has no open items._

`octopus run` shipped in v1.25.0. DAG-based parallel execution via enriched plan format; `PipelineRunner` in `cli/control/pipeline.py`; `octopus control --plan` routing.

### Cluster 8 — Control & Run UX Overhaul

_RM-054 complete. Cluster 8 has no open items._

`octopus ask` shipped in v1.26.0 with live streaming, `@role:` prefill in TUI, mini-feed in roster, and cursor-focus output.

### Cluster 9 — Agent Reply (bidirectional interaction)

_RM-055 complete. Cluster 9 has no open items._

Agent reply via `--resume` shipped in v1.27.0. `ProcessManager` captures `session_id`, `[r]` keybinding, `launch_resume()`, reply visible in log.

### Cluster 10 — Octopus Control UX & completeness

_RM-045..052 complete. Cluster 10 has no open items._

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

### Cluster 11 — Control reliability & ergonomics

_RM-057..063 complete. Cluster 11 has no open items._

All seven ergonomics gaps shipped in v1.31.0: per-task logs, cancel/retry keybindings, completion notifications, `--model` flag in command bar, `octopus ask --reply`, and daemon mode.

---

### Cluster 12 — Frontend and fullstack bundles

#### RM-065 — `frontend` bundle

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-05-12

Define frontend-specific skills and wire the existing `frontend-developer` role into a
`frontend` bundle. The role exists (`roles/frontend-developer.md`) but no skills target
frontend patterns (component design, accessibility, CSS conventions, testing with RTL/Playwright).

**Rationale:** The setup UX rewrite reorganized bundles by intent. `frontend` was excluded
because skills don't exist yet — this item tracks their creation.

---

#### RM-066 — `fullstack` bundle

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** proposed
- **Added:** 2026-05-12
- **Blocked by:** RM-065

Combine `backend` + `frontend` bundles with `review-contracts` into a `fullstack` bundle
for monorepos that contain both an API and a separate frontend.

**Rationale:** Depends on RM-065 so both developer roles and their skills are available.

---

### Cluster 13 — Rules override consistency & formatter hooks

_RM-067..074 complete. Cluster 13 has no open items._

All eight items shipped together: rule override layering (workspace → personal → project), symlink live-reload for `.local.md`, git hook re-assembly for concatenate mode, Copilot/Codex native rules delivery, auto-configured rules references in agent config files, and bundle-aware formatter hooks with project override support.

---

### Cluster 14 — Engineering process skills

Octopus today covers **audit + doc lifecycle + release**. It is thin
on the **individual engineering process** layer that frames how a
developer (or an agent acting as one) makes decisions inside a single
session: grilling a plan against the project's domain model, running
TDD as a standalone discipline, finding deep-module refactor
opportunities, mapping unfamiliar territory, triaging incoming issues,
synthesising a conversation into a PRD, building throwaway prototypes,
handing a session off to the next agent, and authoring new skills.

The nine items below add that layer with names that follow our
`verb-noun` / family-prefix convention (`doc-*`, `test-*`,
`refactor-*`, `context-*`, `*-skill`) and slot each skill into an
existing bundle so no skill ships loose. Four also get explicit
`commands/` slash-commands (`doc-prd`, `triage-issues`, `prototype`,
`context-handoff`) — the ones likely to be invoked by name rather
than discovered through automatic skill routing.

#### RM-075 — `doc-align` skill

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** shipped (v1.45.0)
- **Added:** 2026-05-19
- **Bundle:** `docs`

Interactive grilling skill that stress-tests a plan against the
project's **CONTEXT.md glossary** and `docs/adr/` decisions, surfacing
contradictions between user claims and the actual code, and updating
CONTEXT.md / ADRs **lazily** as terms get resolved.

**Design pillars:**

- CONTEXT.md is **glossary only** — never spec, never scratchpad
- ADR **triple gate**: hard-to-reverse **and** surprising-without-context
  **and** real trade-off; missing any one cancels the ADR
- When code diverges from user's claim, surface the contradiction
  immediately rather than continuing the question chain
- Composes with `doc-prd` and `refactor-deepen`

---

#### RM-076 — `test-tdd` skill

- **Priority:** 🟠 High
- **Effort:** medium
- **Status:** shipped (v1.45.0)
- **Added:** 2026-05-19
- **Bundle:** `starter` (pairs with `implement`)

Standalone red-green-refactor loop with vertical tracer-bullet slices
and integration-style tests targeting the public interface. Today TDD
only exists embedded inside the `implement` skill; this extracts it so
debug sessions and isolated bugfixes can use the loop without the full
`implement` workflow.

**Design pillars:**

- Named `test-tdd` to sit beside the existing `test-e2e` family
- Hard ban on **horizontal slicing** (all tests then all code) —
  rationale: horizontal slicing tests imagined behaviour and breaks
  on internal renames
- "Never refactor in red" as a non-negotiable phase gate
- Test vocabulary comes from CONTEXT.md
- Explicit confirmation step with the user on **what is worth testing**

---

#### RM-077 — `refactor-deepen` skill

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** shipped (v1.45.0)
- **Added:** 2026-05-19
- **Bundle:** `quality`

Find **deepening opportunities** — shallow modules with interfaces as
complex as their implementations, micro-modules with no locality,
pure-function extractions made only for testability. Presents a
numbered candidate list (files / problem / solution / benefits)
**without proposing interfaces**, then enters a grilling loop on the
chosen candidate via `doc-align`.

**Design pillars:**

- **Deletion test**: imagine deleting the module; if complexity
  disappears it was pass-through, if it reappears in N callers it
  was load-bearing
- **"One adapter = hypothetical seam; two adapters = real seam"**
- Enforced canonical vocabulary (Module / Interface / Implementation /
  Depth / Seam / Adapter / Leverage / Locality) — forbid drift to
  "component / service / boundary"
- Vocabulary table + signal catalog + worked examples split into
  REFERENCE.md

---

#### RM-078 — `map-system` skill

- **Priority:** 🟢 Low
- **Effort:** low
- **Status:** shipped — skill v1.45.0, command v1.46.0
- **Added:** 2026-05-19
- **Bundle:** `starter` (transversal utility)

One-shot skill that produces a higher-level map of relevant modules
and their callers when the agent does not know the area of the code,
expressed in the project's domain language.

**Design pillars:**

- **Manually-invoked only** — agents must not zoom-out on their own
  initiative
- Output stays in CONTEXT.md vocabulary, not implementation jargon
- Skill body itself short — most of the value is the invocation
  discipline, not the prose

---

#### RM-079 — `triage-issues` skill + `/octopus:triage-issues` command

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** shipped (v1.45.0)
- **Added:** 2026-05-19
- **Bundle:** `docs`

State-machine triage flow with explicit categories (`bug` /
`enhancement`) and states (`needs-triage`, `needs-info`,
`ready-for-agent`, `ready-for-human`, `wontfix`).

**Design pillars:**

- Every AI-generated comment carries a **mandatory disclaimer**:
  `> *This was generated by AI during triage.*`
- **Reproduce bugs before grilling** — failure to repro is a strong
  `needs-info` signal
- Rejected enhancements go into a permanent `.out-of-scope/` record
  so the same suggestion is not re-litigated
- `needs-info` notes preserve "Established so far" so grilling work
  is not lost when blocked on the reporter

---

#### RM-080 — `doc-prd` skill + `/octopus:doc-prd` command

- **Priority:** 🟠 High
- **Effort:** medium
- **Status:** shipped (v1.45.0)
- **Added:** 2026-05-19
- **Bundle:** `docs` (`doc-*` family)

Synthesise the current conversation context into a PRD and publish it
to the issue tracker **without re-interviewing the user** — the
knowledge is assumed to be already in context from a prior brainstorm
or grilling.

**Design pillars:**

- **No file paths or code snippets in the PRD body** — they rot fast,
  with the explicit exception of snippets from prototypes that encode
  a decision more precisely than prose
- Skips directly to `ready-for-agent` — no re-triage round
- User-stories section is **exhaustive**, not representative
- Reuses the publication layer already used by `doc-rfc`

---

#### RM-081 — `prototype` skill + `/octopus:prototype` command

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** shipped (v1.45.0)
- **Added:** 2026-05-19
- **Bundle:** `starter` (design-time discipline)

Throwaway code to answer **one** design question. Bifurcates by
question type: logic/state → runnable terminal app; UI/look →
multiple variants toggleable from one route.

**Design pillars:**

- "Throwaway from day one, and clearly marked"
- **No persistence by default** — in-memory state, because
  persistence is what is being tested, not assumed
- Always surface the state after each action / variant switch
- The single most important deliverable is the **answer**, not the
  code — capture it durably before deleting
- Branch details + worked examples split into REFERENCE.md

---

#### RM-082 — `context-handoff` skill + `/octopus:context-handoff` command

- **Priority:** 🟢 Low
- **Effort:** low
- **Status:** shipped (v1.45.0)
- **Added:** 2026-05-19
- **Bundle:** `starter` (sits next to `context-budget`, family
  `context-*`)

Compact the current conversation into a handoff document another
agent can pick up, with **suggested skills** for the successor to
invoke.

**Design pillars:**

- Save to the OS tmp dir, **not the workspace** — handoffs do not
  pollute the repo
- Reference existing PRDs / plans / ADRs / issues / commits by
  path/URL — never duplicate their content
- Mandatory redaction of secrets / PII
- The "suggested skills" section is prescriptive, not optional
- Tie-in with `/octopus:delegate`

---

#### RM-084 — `interview` skill + `/octopus:interview` command

- **Priority:** 🟠 High
- **Effort:** low
- **Status:** shipped (v1.47.0)
- **Added:** 2026-05-19
- **Bundle:** `docs`

Interactive requirements interview — one question at a time, walking
the decision tree of a new feature until shared understanding. The
**greenfield** counterpart to `doc-align` (which validates an
existing plan against existing docs). No dependency on `CONTEXT.md`
or `docs/adr/`. Closes the original gap analysis item missed in the
initial Cluster 14 batch.

**Design pillars:**

- One question per turn — never batch, never "and also…" hedge
- Prefer open-ended over yes/no — open-ended surfaces unknowns
- Anchor on a one-sentence root statement before branching
- Visible decision-tree recap every 3–5 questions, sharing format
  with `triage-issues` `needs-info` notes
- Recognise tree resolution and stop — do not pad with "be thorough"
- Hands off to `doc-align` (validate against docs), `doc-prd`
  (package as ticket), or `implement` (start work immediately)

**Natural flow:** `interview → doc-align → doc-prd → implement`.

---

#### RM-083 — `scaffold-skill` skill

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** shipped — skill v1.45.0, command v1.48.0
- **Added:** 2026-05-19
- **Bundle:** `docs` (sits next to `compress-skill`, family `*-skill`)

Create new Octopus skills with the correct structure (frontmatter +
SKILL.md ≤ 250 lines with target 150 + optional
REFERENCE/EXAMPLES/scripts) and progressive disclosure. Complements
`compress-skill` (which modifies existing skills).

**Design pillars:**

- The `description` is **the only thing the agent sees when picking
  a skill** — enforce shape (capability + "Use when" triggers) with
  bad/good example pair built into the skill itself
- **Scripts beat generated code** for deterministic operations
- References stay **one level deep** — no recursive linking trees
- **Octopus-specific extension:** must register the new skill into a
  target bundle as part of the flow — no skill ships loose
- Description-writing rules + review checklist split into REFERENCE.md

---

### Cluster 15 — Claude Code in large codebases (article-parity)

Gap analysis against Anthropic's *"How Claude Code Works in Large
Codebases — Best Practices and Where to Start"*
(<https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start>).
Octopus already covers most of the article's recommendations
(skills, hooks, subagents, MCP templates, plan-before-code, codebase
maps, plugin/marketplace distribution, restart/handoff, continuous
learning). Three gaps stand out as worth closing; one is parked
pending explicit demand.

#### RM-085 — Subdirectory CLAUDE.md tooling

- **Priority:** 🟠 High
- **Effort:** low-medium
- **Status:** shipped (v1.50.0)
- **Added:** 2026-05-19
- **Bundle:** `docs` (next to `doc-adr`, `doc-lifecycle`)

The article emphasises subdirectory CLAUDE.md as a top scaling
practice (*"Initialize CLAUDE.md in subdirectories, not repo
root"*) — local conventions for a module live next to the module,
keeping the root file lean. Octopus today generates only a
root-level CLAUDE.md; large monorepos using Octopus inherit the
limitation.

**Design pillars:**

- New skill `doc-subcontext` + command `/octopus:doc-subcontext
  <path>` following the established `doc-*` family pattern
- Reads the parent CLAUDE.md to avoid duplication; asks for the
  conventions **unique to that area** only
- Writes `<subdir>/CLAUDE.md` lean (~50–100 lines)
- Pairs with `compress-skill` for periodic shrinking
- Registered in the `docs` bundle

---

#### RM-086 — Stop hook for CLAUDE.md / knowledge update proposals

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** shipped (v1.51.0)
- **Added:** 2026-05-19
- **Surface:** `hooks/stop/` + `commands/`

**Viability check confirmed:** Claude Code Stop hooks receive
`transcript_path` on stdin JSON, pointing at a JSONL file with all
user + assistant turns and tool calls. The hook parses it with `jq`,
detects the three signals (corrections, re-reads ≥3×, re-greps ≥3×),
and writes proposals when any signal exceeds threshold.

The article highlights *"Stop hooks to propose CLAUDE.md updates"*
as a self-improvement loop. Octopus has the `continuous-learning`
skill but it engages only when the user invokes it; sessions that
surface a recurring pattern often end without that pattern getting
written down.

**Design pillars:**

- New `hooks/stop/propose-knowledge-update.sh` — at session end,
  detects user corrections, facts the agent had to re-discover, or
  recurring rule-violation patterns, and writes a proposal to
  `.octopus/proposals/<timestamp>.md`
- Proposals are **reviewed manually before merge** — no auto-edit
  of CLAUDE.md / knowledge files
- New `/octopus:review-proposals` slash command walks the queue
- **Feasibility check required:** does Claude Code expose the
  session transcript to Stop hooks? If not, the hook degrades to a
  "session-end ping" that just opens `continuous-learning` —
  still useful but less ambitious

---

#### RM-087 — Configuration freshness audit

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** shipped (v1.50.0)
- **Added:** 2026-05-19
- **Bundle:** `quality` (next to `audit-all`, `refactor-deepen`)

The article calls for 3–6 month config audits, citing that rules
written for older models can constrain newer ones (*"Rules
enforcing single-file refactors may help older models but prevent
newer ones from making coordinated cross-file edits"*). Octopus
has `plan-backlog` (audits plans) and `audit-all` (audits code)
but nothing audits the configuration surface itself.

**Design pillars:**

- New skill `audit-config` + command `/octopus:audit-config`
- Scans `rules/`, `skills/`, `hooks/`, `commands/`, `bundles/` for:
  (a) date references older than ~9 months without follow-up;
  (b) model-specific assumptions (e.g. "Opus 3", "Claude 3.5");
  (c) skills with no triggers and no description-driven hints;
  (d) hooks that haven't been touched since a model-family change;
  (e) commands that reference deprecated paths (the recent
  `docs/superpowers/plans/` cleanup is the canonical example)
- Output mirrors `audit-all`: severity-tiered report
  (block / warn / info)
- No model calls needed for the basic version — file scanning +
  heuristics only

---

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

---

## In Progress

_No items in progress. All clusters complete through RM-087.
Cluster 14 (RM-075..084) shipped across v1.45.0 → v1.49.0.
Cluster 15 (RM-085..087) shipped across v1.50.0 → v1.51.0
(viability check for RM-086 confirmed Stop-hook transcript
availability)._

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
