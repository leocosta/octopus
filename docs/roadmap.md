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

### Cluster 21 — Semantic quality/style signal

_**Implemented** (added 2026-06-02). Seeds from [research](research/2026-06-02-audit-style-rules-aware.md): the RM-088 PRD was titled "Quality, Style **& Grounding**" but shipped only the syntactic block (`guardrails`) and the semantic **grounding** signal (`audit-grounding`). The semantic **design/quality** signal — judging conformance to the opinionated rules in `rules/common/*` and flagging over-engineering — was never built. The native `/simplify` cannot fill it (no project rules, no memory across runs, and it may itself introduce the over-abstraction the rules forbid). The fix is the `audit-grounding` shape pointed at a different source of truth: the house rules._

| RM | Item | Theme |
|----|------|-------|
| RM-112 | `audit-style` skill — semantic, signal-only reviewer confronting the diff against the opinionated design rules (`exceptions.md` gate G1/G2/G3, Result-vs-throw, boolean-param→options, magic numbers, guard clauses, layer separation) + active stack rules, with an explicit **anti-over-engineering** dimension (premature abstraction, speculative hierarchy, DRY-before-three). Mirrors `audit-grounding` (signal-only, `warn`/`info`, structural tests); registers in `quality`, orchestrated by `codereview`/`pr-review`/`implement`; **no new Stop hook**. Recurring findings reuse the existing `continuous-learning`/`review-proposals` loop (RM-093 at team level) → rule/CLAUDE.md candidates | local guardrail |

_Decisions: positioned as an `audit-*` sibling (not a `simplify` wrapper); skill-only (no per-session hook, and **not** part of `audit-all`'s domain dispatch — like `audit-grounding`/`audit-verification`, it runs via the review flows); knowledge loop reused, not a new RM. Distinct from `refactor-deepen` (deepens design) and native `/simplify` (generic taste, applies fixes). Implemented: `skills/audit-style/SKILL.md`, `quality` bundle, EN+pt-br docs pages, `tests/test_audit_style.sh`._

---

### Cluster 22 — CLI surface hygiene

_Proposed (added 2026-06-02). Seeds from [research](research/2026-06-02-cli-surface-hygiene.md): a question — "the CLI accepts params not in the help; which, and why?" — surfaced a structural gap, not a docs gap. `cli/octopus.sh` infers commands from file existence (`source cli/lib/<cmd>.sh`, no allowlist), so every lib is an accepted command — including helper libs that silently no-op — and the help is split across two hand-maintained, drifting layers (`bin/octopus` shows 5 commands; the 17 workflow commands appear only on bare `octopus`). Conventional affordances are missing (`octopus --version` prints "Unknown command"; no per-command `--help`), and `doctor` is anemic. The keystone is a declarative command registry that both guards the dispatch and generates the help; the rest builds on it. Build order: RM-113 → RM-114/115; RM-116 is independent._

| RM | Item | Theme |
|----|------|-------|
| RM-113 | Command registry + generated help + lib guard — replace "command = a `cli/lib/*.sh` exists" with a declarative registry (central list or `# @command:` marker); dispatch validates against it (helper libs error instead of no-op); help is **generated** from it and **unified** (`octopus help`/`--help` lists every command, ending the two-layer `bin/octopus` vs `cli/octopus.sh` split). Single source of truth for dispatch guard + help; kills the drift at the source | foundation |
| RM-114 | Conventional CLI affordances — `octopus version`/`--version` (today errors "Unknown command"), `octopus help <cmd>` + `--help`/`-h` per subcommand, `octopus list` (generated), `octopus completions [bash\|zsh\|fish]`. Enabled by RM-113's registry; `version` trivial, `completions` heaviest/lowest | conventions |
| RM-115 | Document the hidden-but-real surface — a "Configuration / Environment" section for the `OCTOPUS_*` env vars, the full `setup` flag set (`--no-hooks`/`--no-workflow`/`--bundle`/`--stack`/`--reviewers`), and the `release` subcommands; bilingual docs-site pages. Mostly docs; part auto-covered by RM-113's generated help | docs |
| RM-116 | `octopus doctor` as the health command — grow it from version/path into read-only detection: stale hook paths in `settings.json` (version-pinned `cache/vX.Y.Z` entries pointing at a deleted release — the class fixed in `deliver_hooks`), rotten cache symlinks, version drift across repos, stale translations. Reuses `audit-config`. Independent of the registry | health |

_Decisions: the `bin/octopus` shim vs `cli/octopus.sh` workflow split is intentional (bootstrap/version-management vs workflow) — RM-113 unifies the **help**, not the binaries. Registry is opt-in (explicit), not opt-out, so the "file = command" coupling that caused the problem is removed. Implementation libs (`knowledge-*`, `consigliere-lens`, `audit-map`, `ui`, `setup-picker`) stay internal — the registry simply omits them._

_**Cluster 22 implemented** (RM-113…116):_
- _**RM-113** — `cli/lib/commands.default` (pipe-delimited registry mirroring `knowledge-roots.default`); `cli/octopus.sh` generates its help from it and rejects any unregistered name (helper libs no longer no-op); `bin/octopus` `print_help` reads the registry so `octopus help` lists global + workflow commands; `help` is first-class. Tests: `tests/test_cli_registry.sh`. Released v1.76.0._
- _**RM-114** — `octopus version`/`--version`, `list`, `help <cmd>` (registry summary), `completions [bash\|zsh\|fish]`. `<cmd> --help` defers to the command's own handler. Tests: `tests/test_cli_affordances.sh`._
- _**RM-115** — `docs/site/reference/cli.mdx` (EN+pt-br): global/workflow commands, full `setup` flags, `release` subcommands, `OCTOPUS_*` env vars; new Reference > CLI Reference sidebar entry._
- _**RM-116** — `octopus doctor` health checks: stale hook paths in `settings.json`, broken cache symlinks, version drift (best-effort). Read-only, never hard-fails on findings. Tests: `tests/test_doctor.sh`. (The setup-side self-heal lives on branch `fix/stale-hook-settings-paths`.)_

---

### Cluster 23 — Token-cost optimization (max usage efficiency)

_**✅ Implemented** — shipped fleet-wide in **#172** (2026-06; RM-117–137), with RM-130's audit `model:` tiers + the opus alias bump completed in **#203**. Measured cut: always-loaded **8,407 → 2,905 tok (−65%)**, total/session **~16,800 → ~9,398 (−45%)**, core↔rules dup **3 → 0**; locked against regression by `scripts/context-budget.sh` + `tests/test_context_budget.sh`. Originally proposed 2026-06-03. Seeds from [research](research/2026-06-03-token-cost-optimization.md): a measured pass over the always-loaded surface and the fan-out orchestrators. The baseline is **~8.4k tokens/session/repo** (`.claude/CLAUDE.md` ~14.5 KB + `rules/common/*` ~19.2 KB) with **confirmed duplication** — `core/guidelines.md` (inlined into the generated CLAUDE.md as `{{CORE}}`) repeats Principles/Security/Testing already expanded in `rules/common/*`. At ~30 sessions/day × 6 repos that is ~7.5M tokens/month of cold re-injection. Governing fact: `.claude/CLAUDE.md` is **generated** by `setup.sh::generate_from_template()` from the `agents/claude/CLAUDE.md` template + `core/*.md`, so every fix edits the **source** and regenerates, never the generated file. Decision: **aggressive** (full progressive disclosure + lang-split + model tiering), shipped as the **baseline default for all repos**. Deepens Clusters 1 (RM-022) & 2 (RM-025/026), which closed individual wins. Build order: RM-131 (measurement) first → Item-1 baseline (RM-117→121) → orchestrators (RM-122→126) → registry/tiering (RM-127→130)._

| RM | Item | Theme |
|----|------|-------|
| RM-117 | Dedup `core/guidelines.md` ↔ `rules/common/{coding-style,security,testing}.md` — rewrite `{{CORE}}` to **reference** the canonical/expanded rules instead of repeating Principles/KISS/DRY/Anti-Patterns/Security/Testing; regenerate via `setup.sh`. ~1.5k tok/session, zero coverage loss | baseline |
| RM-118 | Move `rules/common/exceptions.md` (9.3 KB / ~2.3k tok) to on-demand — the G1–G4 gate + C#/Py/TS examples only matter when introducing `class XException`/`raise`/`throw new`; attach to `audit-style` (RM-112) skill/`REFERENCE.md`, trigger on those patterns, drop from baseline symlink | baseline |
| RM-119 | Thin CLAUDE.md — stop inlining reference material (`commit-conventions`, `pr-workflow`, `task-management`, `architecture`) in `{{CORE}}`; load on-demand from the commands that use them (`commit`, `pr-open`, `triage-issues`, `doc-adr`). Adjust `generate_from_template()` (`CORE_FILES`) + template. Target generated CLAUDE.md ~14.5 KB → ~3–4 KB | baseline |
| RM-120 | Lang-split rules — load `rules/<stack>/**` + minimal `common` per repo via stack profile in `.octopus.yml`/bundles + `setup.sh::deliver_rules`; reuse existing `rules/{csharp,python,typescript}/` and the package-manager detection in `load-context.sh`. Mono-stack repos stop loading other languages' guidance | baseline |
| RM-121 | Compress remaining `rules/common` — deterministic `compress-skill` pass + `context-budget` over the post-dedup files; ~15–25% off the residual block, meaning preserved | baseline |
| RM-122 | Subset-route the review fan-out — `codereview`/`pr-review` send each audit/role only its domain-matching file subset (mirror `audit-all` + `skills/_shared/audit-output-format.md`) instead of the full diff to all 6 agents. ~40–60% of diff tokens | orchestrators |
| RM-123 | Gate dispatch on the zero-LLM audit map — feed `cli/lib/audit-map.sh` (already used by `pre-push-audit-suggest`) into `codereview`/`pr-review` to dispatch only matched audits; `architect` conditional on size/risk, not always-on | orchestrators |
| RM-124 | Single-pass review for small PRs (< ~150 lines) — one consolidated reviewer, diff read once, instead of fan-out | orchestrators |
| RM-125 | `audit-all` default = triggers-matched audits (not the fixed 4) + memoize by SHA to skip re-audit of an unchanged ref (reuse `skills/_shared/audit-cache.md`) | orchestrators |
| RM-126 | `dev-flow` — make expensive steps opt-in (Step 3 self-review, Step 6 release); run self-review only pre-merge, not every iteration | orchestrators |
| RM-127 | Bundle-per-stack delivery — deliver only the skills/roles the repo's stack needs (backend repo doesn't list frontend/vercel/launch-*); reuse `bundles/` + `expand_bundles`/`deliver_skills`. Trims the ~117-item session registry to what's reachable | registry |
| RM-128 | Trim `description:` frontmatter across ~117 skills/commands to one dense line (it's the text the session registry lists) | registry |
| RM-129 | Consolidate families (`audit-*`/`doc-*`/`knowledge-*` sub-modes) + remove skill↔command redundancy (items duplicated in both `skills/` and `commands/`) | registry |
| RM-130 | ✅ **Implemented** (dispatch wording #172; audit `model:` tiers #203) — each `audit-*` skill declares a `model:` tier (domain audits → `sonnet`, signal/config → `haiku`; never Opus), honored by `skill_matcher.py` and by the `codereview`/`pr-review` dispatch (spawns each audit as a sub-agent on its declared tier); adjudicating roles (`architect`/`dba`/`security`) stay Opus. Biggest **$** multiplier on the 6-agent fan-out. Tests: `tests/test_model_tiering.sh` | cross-cutting |
| RM-131 | Measurement harness + CI budget check — extend `context-budget` to report tokens (CLAUDE.md, each `rules/**`, registry-description sum, total) + `tests/test_context_budget.sh` failing over a ceiling (CLAUDE.md > 4 KB; any core↔rules dup). **Build first**: provides before/after for every RM and stops silent regrowth | cross-cutting |

_Decisions: edit source + regenerate (never the generated `.claude/CLAUDE.md`); baseline-for-all (not opt-in) with safety via the RM-131 budget check + cross-stack verification (C#/Python/TS); Stop hooks excluded (zero-LLM, deferred cost). Reuses existing machinery — `context-budget`, `compress-skill`, `skills/_shared/*`, `cli/lib/audit-map.sh`, `rules/{csharp,python,typescript}/` — rather than new abstractions._

_**Cluster 23 complete** on `perf/token-cost-optimization` (added 2026-06-03). All 15 RMs (RM-117…131) landed. Measured per-session cut (corrected counter): **always-loaded 8407 → 2905 tok (−65%)**, **registry 8013 → 6137 tok (−23%)**, **total ~16420 → ~9042 tok (−45%)**, `core↔rules` dup 3 → 0. The `test_context_budget` ratchet enforces it; touched tests green (5 unrelated failures pre-exist on `main`: `test_workflow_commands`, `test_concatenate_agent`, `test_respond_to_review`, and the `mktemp`-env flakes `test_commands`/`test_hooks_injection`)._

_Key finding: the **registry listing** (every skill/command `description:`, loaded each session) was the biggest single cost — 8013 tok — and the first-line budget counter was blind to multi-line `description: >` blocks (RM-128 fixed the counter, then trimmed 42 descriptions). The always-loaded baseline work (RM-117/118/119/121) is the larger structural win._

- _**RM-131** — `scripts/context-budget.sh` (source-based) + `tests/test_context_budget.sh` ratchet._
- _**RM-117** — `core/guidelines.md` → pointer; principles/security/testing load once via `rules/common`. 8407 → 7989._
- _**RM-119** — `core` symlink delivery (`.claude/core/`) for template agents; only the pointer stays inline. CLAUDE.md 3199 → 628; 7989 → 5418._
- _**RM-118** — `exceptions.md` on-demand (`ON_DEMAND_RULES`). 5418 → 3089._
- _**RM-121** — compress `rules/common` prose (patterns/security/testing). 3089 → 2905._
- _**RM-122/123/124** — `codereview`/`pr-review`: subset-route per domain, gate dispatch on `audit-map`, single-pass small PRs._
- _**RM-125/126** — `audit-all` skips empty-subset audits; `dev-flow` self-review opt-in/pre-merge._
- _**RM-130** — `audit-*` tiered to the cheapest model; roles keep Opus._
- _**RM-120/127** — lang-split + bundle-per-stack guarantees locked by `test_lang_split.sh` (mechanism pre-existed; coupling rules into intent bundles rejected as a design regression)._
- _**RM-128** — registry counter fixed + 42 descriptions trimmed to activation hints (24 verbose + 18 mid-size). 8013 → 6137._
- _**RM-129** — `test_command_delegation.sh` locks the skill↔command delegation pattern (no always-loaded token to reclaim; bodies are on-demand)._

_Follow-up vectors (RM-132…135, same branch — found by auditing what Cluster 23 didn't touch):_
- _**RM-134** — harness now counts **role descriptions** (listed as agents every session, +~398 tok, previously invisible) and **per-stack rule budgets** (csharp/python/typescript), with ratchets._
- _**RM-133** — trimmed the 4 verbose role descriptions (consigliere/mentor/dba/security). registry 6535 → 6493._
- _**RM-132** — stack rules turned out **example-heavy** (code is the value) with terse prose; only safe automated cut was the csharp override boilerplate (3463 → 3353). python/typescript left intact rather than gut examples._
- _**RM-135** — guard for SKILL.md bodies over the 250-line guideline (on-demand cost); `respond-to-review` compressed 313→213 (also fixed a pre-existing `Batching` test gap), oversized 4→3. The other 3 (dotnet/delegate/launch-release) are example/template-heavy — left and locked._
- _**RM-136** — narrowed over-broad `triggers:` (consumed by setup for the concatenate-agent stub decision): dropped `paths: ["**/*"]` on audit-grounding/style/verification and common-word keywords (token/sql/org/workspace/price/checkout/pattern/knowledge/plan) so concatenate agents stub them in repos that don't use them. No effect on Claude Code (description-driven)._
- _**RM-137** — `implement` trivial-change fast path: a typo/rename/config bump (no testable behavior, nothing in data/auth/money/tenant/contract) skips the full five-practice loop. Cuts routine overhead on the highest-frequency auto-activated skill, the real per-task cost on Claude Code._

---

### Cluster 24 — Stack-aware, granular setup

_Proposed (added 2026-06-04). Seeds from [research](research/2026-06-04-stack-aware-setup.md): `octopus setup` installs coarsely and never detects the stack. `.octopus.yml` only gets `rules:` via the hardcoded `--stack` flag (no repo scan, no picker stack selection); intent bundles (`backend`/`fullstack`) pull all four `dba-*` regardless of DB; `starter`/`quality` ship situational skills atomically. `fleet-bootstrap` already auto-detects stack profiles (`*.csproj`→dotnet, `package.json`→node, `pyproject.toml`→python) for the multi-repo flow, and the `dba-*` skills carry DB signals in their `triggers.keywords` — the fix brings that detection down into single-repo setup and splits the axes (intent bundle vs stack/db profile). Decisions: detect + confirm in picker; stack/db profiles as a new axis; rebalance defaults (affirmed-DB only, split `quality`, trim `starter`). Build order: detection (RM-138/139) → profiles axis (RM-140/141) → rebalance (RM-142/143) → exclude + tests (RM-144/145)._

| RM | Item | Theme |
|----|------|-------|
| RM-138 | Single-repo stack/DB auto-detection — `_detect_stack()` in `cli/lib/setup.sh` reusing fleet detect signals (`*.csproj`→csharp, `package.json`+framework→typescript, `pyproject.toml`→python) + DB signals from the `dba-*` `triggers.keywords`. Read-only; emits detected stacks+DBs | detection |
| RM-139 | Picker confirmation + manifest population — a **Stack/Database** picker section with detected items pre-checked (`PICKER_STACK`/`PICKER_DBS`); `_setup_generate_manifest` writes resolved `rules:`+`profiles:`, replacing the hardcoded `--stack` case | detection |
| RM-140 | Stack/DB profiles as a setup axis — bundles with `category:` (reuse `expand_bundles`): `stack-csharp` (dotnet + csharp rules), `stack-typescript`, `stack-python`; `db-mssql`…`db-redis` (each its `dba-*`); picker groups by category | profiles |
| RM-141 | Intent bundles go stack-agnostic — remove the 4 `dba-*` from `backend`/`fullstack` (from `db-*` profiles now); remove `dotnet` from the `--stack` hardcode (from `stack-csharp`) | profiles |
| RM-142 | Split the `quality` bundle — `quality-audits` (blocking), `quality-signals` (signal-only + audit-config + refactor-deepen), `knowledge-ops` (knowledge-*); move `fleet-*` to `tech-lead`/`fleet`. `quality` may stay a composer for compat | rebalance |
| RM-143 | Trim `starter` defaults — move `map-system` (manual-only) and `delegate` (situational, 305L) into an opt-in `workflow-extras` bundle; `starter` keeps the core loop | rebalance |
| RM-144 | Manifest `exclude:` — drop listed members from the resolved set after `expand_bundles` (e.g. `exclude: [dba-mongodb]`); picker member-deselect is a stretch | granularity |
| RM-145 | Detection/profile tests + per-profile budget — `test_stack_detection.sh`, update `test_bundles.sh` (no `dba-*` in backend/fullstack), extend `context-budget`/ratchet with a per-bundle/profile budget | verification |

_Decisions: profiles modeled as `category:`-tagged bundles to reuse `expand_bundles` (no new resolver); detection confirmed in the picker, not auto-applied; `quality` kept as a composer of the new sub-bundles to avoid breaking repos that list only `quality`. **Migration:** removing `dba-*` from `backend`/`fullstack` and splitting `quality` is breaking for repos that list those bundles and don't re-run setup — detection re-adds the right `db-*`/stack profiles on the next `octopus setup`/`update`, and `fleet-bootstrap` recomposes the fleet. Edits the source (`cli/lib/setup.sh`, `setup.sh`, `bundles/`, `setup-picker.sh`), never the generated `.octopus.yml`/`.claude/`._

_**Cluster 24 complete** on `feat/stack-aware-setup`. All 8 RMs landed; suite green (86/86 bash + pytest). A C#+MSSQL repo's `octopus setup` now writes `bundles: [starter, …, stack-csharp, db-mssql]` and carries no foreign language/DB._
- _**RM-140** — 7 profile bundles (`stack-csharp/typescript/python`, `db-mssql/postgres/mongodb/redis`); resolve granularly via `expand_bundles`, no new resolver._
- _**RM-138** — `_detect_stack()` in `cli/lib/setup.sh`: stack from file presence, DB from driver signals. Self-contained, tested (`test_stack_detection.sh`)._
- _**RM-139** — detection wired live: `--stack` maps to profiles, auto-detection appends them, picker pre-checks them; `_setup_generate_manifest` writes profiles into `bundles:` (dropped the hardcoded skills:/rules: case)._
- _**RM-141** — `backend`/`fullstack` stack-agnostic: the 4 `dba-*` removed (come from `db-*` profiles); dba reviewer role kept._
- _**RM-142** — split `quality` into `quality-audits`/`quality-signals`/`knowledge-ops` (additive; `quality` stays the full composer)._
- _**RM-143** — trimmed `starter` (9 skills); `map-system` + `delegate` moved to a new opt-in `workflow-extras` bundle._
- _**RM-144** — manifest `exclude:` subtracts a member post-expansion (`_apply_excludes`)._
- _**RM-145** — end-to-end focused-stack guarantee test locks the granularity win._
- _**RM-146** — picker member-deselect (the RM-144 stretch): an opt-in `customize` step lists the skills/roles of the chosen bundles, all pre-checked; whatever you uncheck is written as the manifest `exclude:` and dropped by `_apply_excludes`. Tested via `test_member_deselect.sh` (member union + exclude write + end-to-end drop)._

---

### Cluster 25 — Code-quality metrics / health tracking

_Proposed (added 2026-06-04). Seeds from [interview](specs/2026-06-04-quality-metrics.md): track the health of deterministic code-quality metrics (coverage, cyclomatic complexity, module size, dependency structure) over time and per-PR, motivated by the rising share of harness-authored code but measured identically for every PR. The author gets a **local, non-blocking** read at PR-open with a **dual delta** (vs. last-main baseline = trend; vs. local `main` HEAD = this-PR impact). Numbers are always cheap (tooling, ≈0 tokens); a low-cost model is invoked **only** on a threshold breach. History lives on a dedicated **orphan ref** (`octopus/quality-metrics`), written by a single Action reacting to `push:main` — fresh per-merge, conflict-free (reader/writer split + squash-merge serialization), and never pushing to the protected `main`/`release/*`. Thresholds are **ratchet-by-default + optional absolute** (cf. `.octopus.yml` precedence, ADR-005/RM-069). Adapters are **pluggable via the existing stack detection** (Cluster 24); v1 ships **C#** and **TypeScript**. Packaged as a new `quality-metrics` bundle (measurement axis, sibling to `quality-audits`/`quality-signals`); adapters ship inside `stack-csharp`/`stack-typescript`. Mutation testing, AI/agent attribution, the cross-repo manager dashboard, and a blocking gate are explicitly **out of v1**._

| RM | Item | Theme |
|----|------|-------|
| RM-147 | `quality-metrics` — local PR-time dual-delta read of coverage/complexity/module-size/deps over a per-merge orphan-ref baseline; ratchet+absolute thresholds; LLM curation only on breach; C#/TS adapters; new `quality-metrics` bundle + writer-Action template | completed → #175 |

_Status: **completed (#175, 2026-06-04)**. Spec: [2026-06-04-quality-metrics.md](specs/2026-06-04-quality-metrics.md). Open questions resolved during implementation: tool pinning (`lizard` for complexity+size; `coverlet`→Cobertura and `vitest`→LCOV for coverage; `madge` for TS cycles; `dotnet list reference`+Tarjan for C# cycles, thinner than TS); baseline shape = single `baseline.json` snapshot; an absolute target is authoritative when satisfied (no ratchet on top); low-cost model `claude-haiku-4-5`, overridable via `OCTOPUS_LOW_COST_MODEL`._

_**Cluster 25 complete.** RM-147 landed via #175; suite green (`test_quality_metrics` 60/0 incl. injection guards, pytest 106, context-budget under ratchet, site build green). v1 caveats: adapter integration tests are structural (real tooling not installed locally), `vs_main` is a baseline-proxy approximation, and a security review of the merge closed an awk code-injection from untrusted config/baseline values._

---

### Cluster 26 — code-metrics catalog expansion

_Proposed (added 2026-06-06). Seeds from [research](research/2026-06-06-code-metrics-expansion.md): the v1 (RM-147) shipped four deterministic metrics; an interview scoped the next wave against three pains — code decay (B1), unaddressed readability/best-practices (B2), and unassessed load risk in high-traffic apps (B3). The governing decision was **deterministic over non-deterministic on every branch**: an LLM-scored readability grade and a real load test were both discarded as breaking the "deterministic, ≈0-cost-in-the-common-case, signal-never-gate, dual-delta" contract. Split by effort/risk (leverage-by-effort): the cheap-and-reliable pack ships as v2; the two capabilities needing new infra or risky heuristics are v3. New metric fields land as extra keys in the `octopus/code-metrics` orphan-ref `baseline.json`, enabling cross-repo aggregation at the storage level — exercising it (a manager dashboard) stays out of scope. Build order: RM-148 (v2) → RM-149 / RM-150 (v3, independent)._

| RM | Item | Theme |
|----|------|-------|
| RM-148 | v2 metric pack — debt markers + readability counters + doc coverage | v2 / leverage |
| RM-149 | v3 hotspots — churn × complexity (new git-history capability) | v3 / decay |
| RM-150 | v3 perf-proxy — static performance-risk heuristic for high-traffic paths | v3 / load risk |
| RM-151 | `perf_risk` — detect loops with the brace on the next line (Allman) | follow-up / fix |
| RM-152 | Publish the release public signing key for turnkey GPG verify in CI | follow-up / security |
| RM-153 | Setup stamps the writer-Action's `OCTOPUS_REF` at delivery (kill the hardcoded version) | follow-up / delivery |
| RM-154 | Release signing key rotated (old key retired, unrevocable — passphrase lost) | follow-up / security |
| RM-155 | `install.sh` verifies checksum + signature on the default GitHub path | follow-up / security |

_**Cluster 26 implemented** on `feat/code-metrics-expansion` (#191, pending merge). All three RMs landed as 11 new metrics (9 v2 + hotspots + perf_risk) on both stacks. Key decisions resolved in build: the hardcoded dispatch `case` became a data-driven registry (`cm_metric_spec`: direction|block|field); all new metrics are deterministic shell heuristics (grep/awk/lizard/git), ratchet-only by default; `perf_risk` is `info`-only (never gated); dead-code counts only *marked* dead code; the writer-Action now produces `baseline.json` via `octopus code-metrics --emit-baseline` (shared adapters, zero YAML re-implementation) and runs with `fetch-depth: 0` for the hotspots churn window. Suite: `test_code_metrics` 95/0 (Sections 10–15 added)._

### RM-148 — v2 metric pack: debt markers + readability counters + doc coverage

- **Priority:** 🔴 High
- **Effort:** medium
- **Status:** implemented
- **Added:** 2026-06-06
- **Research:** [code-metrics-expansion](research/2026-06-06-code-metrics-expansion.md)

Add the cheap, low-false-positive deterministic pack to `code-metrics`, covering
B2 (readability) in full and B1 (decay) in part:

- **Debt markers** — counts of `TODO`/`FIXME`, `@deprecated`, *marked* dead code,
  and `eslint-disable`/`#pragma warning disable`.
- **Readability counters** — nesting depth, parameter count, magic numbers, lint
  finding density (`lizard` already covers part; define per-stack adapters for
  the rest).
- **Doc coverage.**

All plug into the existing dual-delta, `.octopus.yml` per-layer config, orphan-ref
baseline, and LLM-on-breach curation. Stacks: C#+TS.

**Open questions for the spec:** ratchet-only vs. optional-absolute per metric
(a legacy repo with 5,000 TODOs must not be born "red"); dead-code counts
*marked* only in v2 (reachability deferred); tooling beyond `lizard` for
magic-numbers and doc-coverage.

**Rationale:** Highest leverage per unit of effort — covers B2 entirely and part
of B1 with near-zero false positives and no new infrastructure. Objective
counters the team cannot contest, which is the point of the B2 pain.

---

### RM-149 — v3 hotspots: churn × complexity

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** implemented
- **Added:** 2026-06-06
- **Research:** [code-metrics-expansion](research/2026-06-06-code-metrics-expansion.md)

Surface the files that change often *and* are complex (churn × complexity) to
pinpoint where decay risk concentrates — the remainder of B1. Requires a **new
capability**: reading git history (today's metrics are snapshot/diff only).

**Rationale:** High reading value and low false-positive, but gated behind new
git-history infrastructure, so it is split out of the v2 pack rather than blocking it.

---

### RM-150 — v3 perf-proxy: static risk heuristic for high-traffic paths

- **Priority:** 🟡 Medium
- **Effort:** high
- **Status:** implemented
- **Added:** 2026-06-06
- **Research:** [code-metrics-expansion](research/2026-06-06-code-metrics-expansion.md)

Address B3 (load risk) *within the contract* — a static PR-time proxy of
performance risk (hot path touched, query-in-loop, new O(n²), allocation on a hot
path), **not** a real load test. Per-language AST heuristic.

**Rationale:** The only B3 survivor (real load testing was discarded as
out-of-contract). Highest effort and **high false-positive risk** of the three,
so deliberately sequenced last.

---

### RM-151 — `perf_risk`: detect Allman-brace loops

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** proposed
- **Added:** 2026-06-06
- **Research:** [code-metrics-expansion](research/2026-06-06-code-metrics-expansion.md)

`cm_perf_scan` only opens a loop's scope when the loop keyword and its `{` share
a line. In Allman-brace codebases — idiomatic C#, where `{` sits on its own line
— no loop is ever "active", so `perf_risk` reads **0** regardless of real
query/alloc-in-loop or nested loops. Found while configuring a real C# repo
(`tatame`): `perf_risk` was 0 across the whole api.

Fix: track a *pending loop* across the opener line and the next `{` (look-ahead),
so an Allman `foreach (...) \n {` registers the loop scope. Keep it info-only.
Add a C# Allman fixture to `test_code_metrics.sh`.

**Rationale:** Without this, `perf_risk` is dead weight for the entire .NET
fleet — the stack the metric most needs to serve (high-traffic APIs).

---

### RM-152 — publish the release public signing key (turnkey CI GPG verify)

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** implemented
- **Added:** 2026-06-06

_**Implemented.** The signing key was published to **keys.openpgp.org**
(out-of-band, per the spec — not committed to the repo) with the email verified
so the UID is served. Fingerprint `A146CD8A4E3B132E7653DBF65BD2508E6319D976`. The
writer-Action now fetches the key by full fingerprint (`gpg --recv-keys`),
downloads the signed release tarball, runs `gpg --verify` **fail-closed**, and
runs `cli/octopus.sh` from the verified tree — no `curl install.sh | bash` of an
unverified script. Verified end-to-end against v1.84.1 ("Good signature"). The
fingerprint is pinned in the consumer's workflow (the anchor a compromise of
Octopus can't reach)._

The `code-metrics-writer` template installs the CLI via the official installer
pinned to a release tag; the installer always verifies the tarball SHA-256, but
**GPG signature verification (maintainer authenticity) needs the public key in
the runner's keyring** — and the project does not publish that key anywhere
convenient today (the private key is a GH Actions secret; only the signing
*pipeline* exists, RM-009/RM-020). So CI currently runs with
`OCTOPUS_SKIP_SIGNATURE=1` (checksum-only), which defends against a corrupted
download but not a repo/release compromise.

Fix: publish the release **public** key (commit `octopus-release.pub` to the
repo *and* attach it as a release asset), document
`OCTOPUS_GPG_IMPORT_KEY`/`OCTOPUS_GPG_KEYRING`, and flip the writer template to
import it + drop the skip. Surfaced configuring `tatame`'s writer: the
pinned-installer switch is checksum-safe, but signature verification is the
piece that closes the supply-chain gap the security review flagged.

**Rationale:** Turns the installer's advertised signing into a guarantee
consumers can actually use — the difference between "the download wasn't
corrupted" and "the maintainer signed this".

---

### RM-153 — setup stamps the writer-Action's pin at delivery

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-06-06

`code-metrics-writer.yml` hardcodes `OCTOPUS_REF` to a specific commit SHA. Two
problems with hardcoding a version in a **distributed** template:

- **Self-reference**: the template lives inside the repo it pins, so it can't
  point at its own release (committing the SHA changes the SHA). It shipped in
  v1.84.0 pinned to v1.83.0's SHA — and v1.83.0 had no `--emit-baseline`, so the
  shipped writer was broken until manually bumped.
- **Staleness**: every consumer repo is frozen at whatever SHA the template
  carried, bumped only by hand, repo by repo.

Fix: the **source** template carries a placeholder (e.g. `{{OCTOPUS_SHA}}`);
`setup.sh`/`deliver_*` substitutes the SHA of the Octopus version *that repo is
installed at* when it writes the file into the consumer repo, and `octopus
update` re-stamps it. Each repo's writer then matches its own installed Octopus,
with no self-reference and no manual drift. Pairs with RM-152 — once the public
key is published, the stamped value can become a release tag with GPG verify
instead of a bare SHA.

**Rationale:** Removes the hardcoded-version smell at the root: a pinned
integrity anchor that is *correct per repo* and maintained by the tooling, not
by hand-editing a fleet of workflow files.

---

### RM-154 — release signing key rotated (old key retired, unrevocable)

- **Priority:** 🟢 Low
- **Effort:** trivial (record)
- **Status:** done
- **Added:** 2026-06-07

The original release signing key (`A146CD8A4E3B132E7653DBF65BD2508E6319D976`,
created 2026-04-19) had its passphrase lost — it existed only in the
`OCTOPUS_RELEASE_GPG_PASSPHRASE` secret (write-only, unrecoverable) and not in a
password manager. CI signing kept working (the secret unlocks it), but the
maintainer can no longer operate it by hand — and crucially **cannot revoke
it** (revocation needs the private key + passphrase).

Rotated 2026-06-07 to a fresh key **`63C35E66917CE4540CD27592C8BA059A0322F3CD`**
(RSA-4096, expires 2028-06-06, clean UID): new keypair generated, both release
secrets updated, public key published to keys.openpgp.org (email-verified), and
the writer-Action pin (`OCTOPUS_FPR`) bumped — shipped in **v1.84.2**, the first
release signed by the new key.

The old key is **retired, not revoked** (passphrase lost). Residual risk is low:
the private key never leaked (it became *inaccessible*, not public), so no one
can sign with it either. Lesson: store the signing passphrase in the password
manager at generation time, not only in the CI secret.

---

### RM-155 — install.sh verifies checksum + signature on the default GitHub path

- **Priority:** 🔴 High
- **Effort:** low
- **Status:** done
- **Added:** 2026-06-07

`resolve_checksum_url`/`resolve_signature_url` in `install.sh` only returned a
URL when `OCTOPUS_INSTALL_ENDPOINT` was set. On the **default** path
(`install.sh --version vX` straight from GitHub) they returned empty, so the
whole verify block was skipped — **SHA-256 and GPG verification were silently
inert, and `OCTOPUS_REQUIRE_SIGNATURE` was a no-op** (it lived inside the
URL-gated block). A consumer running `install.sh --version vX
OCTOPUS_REQUIRE_SIGNATURE=1` got a false sense of safety. Surfaced configuring
`tatame`'s writer, which uses exactly that flow.

Fix: both resolvers fall back to the GitHub release asset URL (mirroring
`resolve_tarball_url`); `OCTOPUS_REQUIRE_SIGNATURE` also fails closed when no
signature URL resolves at all. Verified live against v1.84.2: with the key →
"Signature valid" + install; without the key → fail-closed, no install.
Regression-locked by `tests/test_install_signature.sh`. Ships in v1.84.3.

---

### Cluster 27 — Cross-assistant command parity

_Proposed (added 2026-06-09). Surfaced in use: `/octopus:*` workflow commands (pr-open, pr-review, release, …) show up in Claude Code and OpenCode but not in GitHub Copilot. Root cause is by design — `agents/copilot/manifest.yml` sets `native_commands: false`, so `setup.sh` never materialises `commands/*.md` for Copilot; the only command surface it gets is the text list of user-defined `.octopus.yml` commands appended to `.github/copilot-instructions.md` by `append_commands_section`. Copilot **does** support repo-scoped slash commands as **prompt files** (`.github/prompts/*.prompt.md`) — but only in the IDE clients (VS Code, Visual Studio, JetBrains); the Copilot **CLI** does not ([github/copilot-cli#618](https://github.com/github/copilot-cli/issues/618), closed unimplemented). So parity is achievable for IDE Copilot now, with a text/CLI fallback for the terminal._

| RM | Item | Theme |
|----|------|-------|
| RM-156 | Render Octopus workflow commands as Copilot IDE prompt-files (`.github/prompts/`), with a CLI text fallback | parity / multi-agent |
| RM-157 | `octopus setup` picker offers agent selection (no hand-editing `.octopus.yml`) | setup UX / discoverability |

### RM-156 — Deliver workflow commands to Copilot as prompt-files

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** in progress — [Spec](specs/copilot-command-parity.md), [ADR-011](adr/011-capability-gated-delivery.md)
- **Added:** 2026-06-09

`/octopus:pr-open`, `/octopus:pr-review`, `/octopus:release`, etc. are defined once
in `commands/*.md` and delivered natively only to agents whose manifest declares
`native_commands: true` (Claude → `.claude/commands/`, OpenCode →
`.opencode/commands/`). Copilot's manifest is `native_commands: false`, so those
commands never reach it — the user sees no `/pr-open` in Copilot.

GitHub Copilot **does** support repo-scoped slash commands as *prompt files*
(`.github/prompts/<name>.prompt.md`, invoked as `/<name>` in chat) — but only in the
IDE clients (VS Code, Visual Studio, JetBrains). The Copilot **CLI** has no
equivalent yet (feature request github/copilot-cli#618, closed without
implementation), so a prompt-file does nothing in the terminal.

Proposal:

- Add a `delivery.commands` rendering path for Copilot (new method, e.g.
  `prompt_files`) that emits each `commands/*.md` to
  `.github/prompts/octopus-<name>.prompt.md`: strip the Octopus `name:`/`cli:`
  frontmatter, add the Copilot prompt frontmatter, and translate the argument
  placeholder (`$ARGUMENTS` → `${input}`). Gate it on a capability
  (e.g. `native_prompt_files`), not on the agent name — keep the manifest-driven
  altitude so JetBrains/Visual Studio reuse the same method.
- Keep a **CLI fallback** for terminal Copilot: extend `append_commands_section`
  (or a sibling) so the workflow commands are listed in
  `.github/copilot-instructions.md` as their `octopus <name>` CLI equivalents.

**Open questions for the spec:** exact prompt-file frontmatter mapping (mode/tools);
argument-placeholder translation across agents; whether the same method also serves
JetBrains/Visual Studio; the `octopus-` prefix to avoid collisions with user prompt
files.

**Rationale:** Closes a visible parity gap for the fleet (6+ repos, mixed
assistants) — the same standards-bearing workflows should be one keystroke away
regardless of which assistant a teammate uses. Extends the manifest-driven
multi-agent architecture; cheap for IDE Copilot, honest about the CLI limitation.

### RM-157 — `octopus setup` picker offers agent selection

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** implemented (this PR — `--agents` flag + picker agent screen)
- **Added:** 2026-06-09

The interactive `octopus setup` picker (`cli/lib/setup-picker.sh`) lets the user
choose bundles, individual skills/roles/rules, hooks, workflow commands, reviewers,
and MCP servers — but **not** which AI assistants to configure. The agent list lives
only in the `.octopus.yml` `agents:` key, so enabling a new assistant (e.g. adding
`copilot`) means hand-editing YAML. The available agents are discoverable as
`agents/*/manifest.yml` (today: `claude`, `codex`, `copilot`, `gemini`, `opencode`),
so the picker has everything it needs to offer them.

Surfaced right after RM-156 made Copilot a first-class command target: the feature
exists, but a user would never discover it from `octopus setup` alone.

Proposal:

- Add an **agent multi-select screen** to the picker (fzf path + bash fallback,
  matching the existing two-path structure), enumerating `agents/*/manifest.yml`
  with a one-line description, defaulting to the current `.octopus.yml` `agents:`
  set, and writing the selection back to `.octopus.yml`.
- Show each agent's headline capabilities (e.g. native commands vs. prompt-files vs.
  instructions-only) so the choice is informed.

**Open questions for the spec:** where the screen sits in the flow (before bundles,
since rules/skills/commands are delivered per agent); how it round-trips the
`agents:` block while preserving long-form `output:` overrides; whether to warn when
deselecting an agent that already has generated files on disk.

**Rationale:** Discoverability — the manifest-driven multi-agent architecture is a
headline feature, but it is invisible in the one place a user configures the repo.
Pairs directly with RM-156 (Copilot parity is moot if nobody can turn Copilot on
without reading the YAML).

---

### RM-158 — `install.sh` self-bootstraps the release key by fingerprint

- **Priority:** 🔴 High
- **Effort:** low
- **Status:** implemented (this PR)
- **Added:** 2026-06-09

`octopus update` on a fresh machine failed with `GPG signature verification
failed for octopus.tar.gz`. Root cause: `verify_signature()` ran `gpg --verify
--no-auto-key-locate` and only passed if the release public key was **already**
in the user's keyring. On a clean box the key is absent, gpg reports "No public
key", and the install/update aborts. RM-155 wired the default GitHub path through
verification — which is exactly why the missing key now surfaced as a hard error
instead of being silently skipped.

The writer-Action (RM-152) already solved this in CI by fetching the key by its
**full fingerprint** (`gpg --recv-keys`) — the out-of-band pin, since a keyserver
cannot serve a different key for a given fingerprint. The fix gives the installer
the same self-bootstrap:

- Pin `OCTOPUS_RELEASE_FPR` (`63C3…F3CD`, the rotated v1.84.2+ key, RM-154) and
  fetch it from `OCTOPUS_GPG_KEYSERVER` (default `keys.openpgp.org`) when absent.
- Verify via `--status-fd` and require `VALIDSIG` from the **pinned** primary
  fingerprint — a foreign key already in the user's keyring can no longer satisfy
  verification on the default path.
- **Graceful degradation:** if the key can't be obtained (offline / unreachable
  keyserver), warn and continue on SHA-256 only; `OCTOPUS_REQUIRE_SIGNATURE=1`
  turns that case into a hard failure for strict consumers (CI).
- Override paths (`OCTOPUS_GPG_KEYRING` / `OCTOPUS_GPG_IMPORT_KEY`) keep their
  bring-your-own-trust-root semantics untouched.

**Rationale:** Closes the last gap between "the installer advertises GPG signing"
and "a clean machine actually verifies it" — without asking users to seed a
keyring by hand. The fingerprint stays the trust anchor; the keyserver is just
transport.

---

### RM-159 — Deliver core workflow commands to the Copilot CLI as custom agents

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** implemented (this PR)
- **Added:** 2026-06-09

RM-156 delivers Octopus commands to Copilot as prompt-files
(`.github/prompts/*.prompt.md`), but those are **IDE-only** — the Copilot **CLI**
does not read them (upstream feature requests: github/copilot-cli #618, #1113,
#2829). So an Octopus workflow like `pr-open` was unreachable from the terminal
under Copilot.

The CLI *does* have a native, no-code extension point: **custom agents**
(`.github/agents/*.agent.md`, markdown + YAML frontmatter), invocable via
`copilot --agent=<name>`, `/agent`, or implicit selection. This delivers a
**selected** subset of workflow commands as `.github/agents/octopus-*.agent.md`.

Design decisions:

- **Selective (option B), not 1:1.** Only terminal-driven workflows ship as
  agents — `dev-flow, implement, debug, commit, branch-create, codereview,
  pr-open, pr-review, pr-comments, pr-merge, release`. The doc-/audit-/knowledge-
  families stay IDE-only; converting all ~46 commands would clutter the `/agent`
  picker and bend the "agent = role" semantics.
- **Capability-gated (ADR-011), not field-gated.** Emission is driven by a
  `native_cli_agents` capability flag (symmetric to `native_prompt_files`), so any
  future agent reuses the renderer with one manifest line and `setup.sh` stays
  agent-agnostic.
- **Selection lives in the copilot manifest**, not the command source
  (`delivery.commands.cli_agents_select`). The canonical `commands/*.md` are read
  read-only, so **other agents' delivery (Claude) is provably unaffected** — a
  test asserts no `.github/agents/` is produced for Claude.
- **Additive, not a replacement.** A selected command gets both an IDE prompt-file
  and a CLI agent.
- **Minimal, version-robust frontmatter** (`name` + `description` only). Copilot
  CLI flags `model`/`argument-hint`/`target` as unsupported across releases
  (github/copilot-cli #1195, #2133); the body is the agent's system prompt, and
  `$ARGUMENTS` is translated to prose (no `${input}` token exists in CLI agents).
- **Anti-collision:** the `octopus-` prefix and prune-by-prefix are scoped to
  `*.agent.md`. Copilot does not deliver role agents today; if it ever does, the
  command set and role set must stay name-disjoint (they are now).

**Rationale:** Closes the last leg of Copilot parity — the terminal-driven
workflows (PR loop, dev-flow, release) now run under the Copilot CLI, not just
the IDE, reusing the same single command source.

---

### RM-160 — Tier the cheap-class non-audit skills off Opus (RM-130 phase 2)

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** implemented (this PR)
- **Added:** 2026-06-11

RM-130 tiered the `audit-*` family; the same gap remained across other skills
whose body already says the LLM step is mechanical/narration but that declared no
`model:`, so they ran on the session model (Opus). A catalogue pass classified
each by the work its LLM step actually does:

- **`model: haiku`** — `knowledge-briefing`, `knowledge-synthesize` (both
  explicitly "run on the cheapest tier / `--model haiku`" in their bodies),
  `knowledge-hygiene`, and `code-metrics` ("low-cost Haiku-class model invoked
  only when a metric crosses a threshold"). Deterministic core + thin narration.
- **`model: sonnet`** — `compress-skill`, `map-system`, `launch-release`,
  `scaffold-skill`, `continuous-learning`, `definition-of-done`. Real reasoning
  over content (semantic rewrite, architecture synthesis, re-voicing, the
  manager grill) but not architecture/code-gen — off Opus, conservatively Sonnet.
- **Kept Opus** — `debug`, `implement` (hands-on reasoning + code generation);
  `consigliere-lens` is already `opus` by design (political "thinks like you"
  judgement). **Skipped** the zero-LLM skills (`enforce-precommit`,
  `consigliere-bootstrap`, `context-budget`) — pure bash, no model call to tier.

The tier is honoured by `cli/control/skill_matcher.py` (the daemon / `octopus`
CLI path, where cadence jobs like `knowledge-briefing --daily` actually run) and
documents the intended tier for any orchestrator that dispatches the skill — the
same mechanism RM-130 used. Locked by `tests/test_skill_tiering.sh`.

**Rationale:** The audit fan-out was the burst cost; this is the steady-state
one — the cadence/knowledge/metrics skills no longer pay frontier-model price for
narration and pattern-matching, with Sonnet reserved where light reasoning helps.

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
| RM-066 | `fullstack` bundle — `backend` ∪ `frontend` ∪ `audit-contracts` for monorepos; `test-e2e` de-duplicated by the expander | completed | 2026-05-27 |
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
| RM-161 | `doc-api` skill + command — on-demand, integrator-facing API contract-fidelity validator and doc generator (code ↔ OpenAPI ↔ business knowledge from ADRs/specs/system-maps); per-version scoping; `--write` updates `openapi.yaml` + integrator reference behind a confirm gate; reuses `audit-grounding`; `docs` bundle; not in `audit-all` | completed → v1.89.0 | 2026-07-18 |
| RM-162 | `doc-api` Assess & Plan flow — `--write` becomes an interactive per-artifact plan (`correct` / `recreate` / `create` / `skip`) over spec + integrator reference, derived from the four checks; `create`-from-scratch is first-class; `breaking` annotates the chosen action before it is applied; validate mode gains a read-only Improvement Plan preview | completed → v1.90.0 | 2026-07-24 |

---

### Cluster 28 — Windows installer parity & hardening

_Proposed (added 2026-07-26). Follow-ups from the Windows installer repair (#212, v1.90.1) and the RM-019 shim-parity refactor (#213, v1.90.2). `install.ps1` now mirrors `install.sh`'s release contract and ships `bin/octopus.ps1` + `octopus.cmd`, but two gaps remain: the Windows delegator shims get no drift signal on `octopus update` (bash-driven, can't see the PowerShell-side bin dir), and `install.ps1` has no behavioral coverage because there is no pwsh/Windows in CI — the invariants test is static-only._

### RM-163 — `octopus doctor` drift-check for stale Windows shims

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** proposed
- **Added:** 2026-07-26

`octopus update` is bash-driven and never refreshes the Windows delegator shims
(`$BinDir/octopus.ps1` + `octopus.cmd`); if the delegation contract changes
(bash discovery / path translation), a stale shim keeps running silently. Add a
`doctor` check that compares the installed shims against
`current/bin/octopus.{ps1,cmd}` and advises re-running `install.ps1` on drift.
Detection-only — self-heal is out of scope (doctor runs under bash and does not
know the PowerShell-side bin dir).

**Rationale:** Closes the one residual gap of RM-019 Windows parity surfaced in
review — the drift is real but currently undocumented and unobservable.

### RM-164 — pwsh CI job for end-to-end `install.ps1` coverage

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-07-26

`tests/test_install_ps1_invariants.sh` is static-only (greps source) because
there is no pwsh/Windows in CI. Add a job that runs the installer end-to-end
under `pwsh` against a `file://` `OCTOPUS_INSTALL_ENDPOINT` fixture (mirroring
`tests/test_installer.sh`), exercising download → checksum → extract → shim
copy → metadata; the bash-delegation tail legitimately stays static.

**Rationale:** Moves the highest-risk path (download / verify / copy) from
grep-asserted to behaviorally verified; pwsh Core runs on Linux, so no Windows
runner is strictly required.

---

### Cluster 29 — Reasoning pressure-test coverage

_Proposed (added 2026-08-01). Audit of Octopus against the classic critical-thinking
techniques found two already covered and two missing. **First-principles** ships as
the `council` advisor of that name (`skills/council/SKILL.md:76`); **red-team** ships
twice over — the whole `council` for ideas, `roles/security.md:97` threat modeling for
code. **Pre-mortem** and **steel man** have no home. `roles/mentor.md:45` deliberately
rejects the ELI5 register ("explain to a capable peer, never condescend"), so that one
is a design decision, not a gap._

_The two items land differently on purpose: pre-mortem **reuses** the council engine
(five divergent lenses map cleanly onto five distinct failure modes), so it is a flag;
steel man reuses **nothing** from it (no divergence to arbitrate, no synthesis to
perform), so it needs its own home._

### RM-165 — `council --pre-mortem` — prospective-hindsight reframe

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** implemented — completed → v1.94.0 (#221, 2026-08-02)
- **Added:** 2026-08-01

Add a `--pre-mortem` flag to `council` that reframes the Phase 1 framed question as a
post-failure autopsy ("it is six months from now and this failed — explain why")
instead of an open decision. Phases 2–3 are untouched: the five existing lenses each
surface a structurally different failure mode — Contrarian the fatal flaw, First
Principles the wrong problem solved, Expansionist the missed window, Outsider the
proposition nobody understood, Executor the first step that never shipped. Phase 4
branches to a pre-mortem verdict shape: failure modes ranked by likelihood × impact,
each with a mitigation and a tripwire, replacing the
`Agrees / Clashes / Blind Spots / Recommendation / One Thing` headings.

Discovery is the flag's weak point — someone wanting a pre-mortem before a launch does
not think "convene a council". Mitigate by extending `triggers.keywords` with
`"pre-mortem"`, `"what could go wrong"`, `"before we launch"`, `"how might this fail"`.

**Rationale:** A separate skill would duplicate ~200 lines of protocol (parallel
dispatch, A–E anonymisation, chairman synthesis) to change one framing paragraph and a
set of headings. The `--transcript` flag already establishes the pattern.

### RM-166 — `steelman` skill — build the strongest case against your own position

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** implemented
- **Added:** 2026-08-01

A standalone skill that constructs the **strongest** version of the opposing argument —
distinct from attacking the idea, which is what `council`'s Contrarian and the
devil's-advocate framing already do. Protocol:

1. **Extract the real position** — what is actually being defended is rarely what was
   stated; steel-manning the wrong position makes the whole exercise noise.
2. **Find the genuine opposition** — the strong contrary, not the convenient strawman.
3. **Build the maximal case** — best available evidence, best framing, the most
   competent critic who would plausibly exist.
4. **Separate what bites from what is rhetoric** — not every strong point is lethal.
5. **Survival test** — "what would you have to believe for your position to still
   stand?" This is where the real weakness surfaces.
6. **Return two buckets** — what demands an answer vs. what can be conceded without
   losing the thesis.

Bundle: `workflow-extras`, alongside `council` — both are situational reasoning
pressure-tests, not per-task work. The skill's primary surface is standalone
(`/octopus:steelman <argument>`), for sharpening a position with no ADR or PR in sight.
One call site reuses the same definition rather than restating it, following the
`audit-all` composer precedent (`skills/audit-all/SKILL.md:60`, "Do not copy"):

- `doc-adr` — `templates/adr.md:22` `## Alternatives Considered` and
  `skills/doc-adr/SKILL.md:112` ask for rejected alternatives, but recording a
  rejection is not steel-manning it; in practice the section degrades to chaff
  ("considered X, too complex"). Require the strong form before the rejection.

`respond-to-review` was evaluated as a second call site and **deliberately excluded**.
Rule 3 (`SKILL.md:57`) would have supplied a clean gate — steel man serves only the
push-back bucket, ~1–2 threads per PR — but the flow already carries diff + comments +
threads, and PR feedback is not where the team wants the extra step. Reviewers who want
it can invoke the skill standalone.

**Invocation — subagent dispatch behind a conditional gate**, applying RM-125
(`skills/audit-all/SKILL.md`: an audit with no domain-matching files is not
dispatched, because "spawning it only burns tokens"). `doc-adr` already owns the gate —
it knows which alternative it is rejecting — so no new heuristic is needed.

Estimated cost (skill sized against `prototype` ~1.1k tok and `interview` ~1.6k tok, so
~1.4k; per-dispatch overhead is an estimate, not instrumented):

| Path | Dispatches | Cost |
|---|---|---|
| `doc-adr`, gated | 1 (the alternative actually being rejected) | ~6k |
| `doc-adr`, ungated (per alternative) | 2–4 | 15–30k |

Inline (reading the skill into the calling context) costs ~1.4k once per session and
does not multiply, but pays that cost **even when unused** — and the common case is an
ADR with no alternative worth steel-manning. For scale, a full `council` run is 11
dispatches; a gated steel man is ~1/10 of that.

**Resolved at implementation — inline, and the measurement was not the deciding
input.** The open question asked for one instrumented dispatch before choosing
subagent vs inline. It was closed on **consistency of execution** instead, which
decides ahead of cost:

- The primary surface is standalone, where the skill runs in the main context like
  every other Octopus prompt-skill. Dispatching the *same* skill from `doc-adr` would
  give it two execution shapes, and the protocol would have to be written for both.
- The `audit-all` precedent does not transfer: it dispatches because each audit sweeps
  a different file subset and the work parallelises. Steel man inside `doc-adr` is one
  piece of reasoning over context already present in an interactive session.
- The output has to become prose in `## Alternatives Considered`; reintegrating a
  subagent's returned text is strictly more work than producing it in place.

For the record, the cost picture was genuinely marginal — inline ~1.4k per session
even when unused, versus ~6k per dispatch when it fires, with break-even around a 23%
usage rate on an uninstrumented per-dispatch estimate. The measurement would only have
flipped the answer if cost were the dominant criterion, and it was not.

**Naming:** `steelman` as a single-word verb, per the `<verb>` foundational-action form
in `skills/scaffold-skill/REFERENCE.md:97` (`debug`, `implement`, `prototype`).
`steel-man` was rejected — the hyphen is orthographic rather than structural and
implies a `steel-*` family that does not exist. `challenge-argument` / `oppose-position`
fit the `<verb>-<noun>` form but connote attacking, which is precisely the distinction
the skill exists to preserve; `test-argument` collides with the `test-*` family;
`pressure-test` would steal `council`'s existing trigger keywords. Jargon opacity is
carried by the `description` plus `triggers.keywords` (`"steel man"`,
`"strongest counterargument"`, `"best case against"`, `"argue the other side"`,
`"where is my reasoning weak"`) — the same trade `consigliere` already makes.
Zero-jargon fallback: `build-counter-case`.

**Rationale:** The capability's home and its injection points are different questions —
binding it only to ADR and PR-review makes it unreachable whenever the trigger is
neither. One canonical definition, three entry points.

---

### Cluster 30 — Growth copy reads as AI-generated

_Proposed (added 2026-08-02). Reported from the outside: the `growth` bundle's output
(`launch-feature`, `launch-release`, `marketer`) is visibly machine-written. The
diagnosis is not that the voice work is missing — v1.93.0 shipped
`skills/_shared/substance-voice.md` plus `substance-lint.sh`, and they are sound. They
just police a **different axis**: hype and manufactured urgency, not the tells that
mark text as LLM output. A passage can clear the substance gate completely and still
announce itself in the first line._

_Demonstrated: a sample carrying `testament`, `pivotal moment`, `serves as`,
`underscoring`, `not just X — it's Y`, `Additionally`, `delves`, `intricate interplay`,
bold inline-header lists, a rule of three, `Industry observers have noted`,
`Despite these challenges` and `The future looks bright` returns
`substance-lint: clean`. None of those terms is hype or FOMO, so nothing fires._

_Reference catalogue: [blader/humanizer](https://github.com/blader/humanizer) — 33
patterns across content, language and style, derived from
[Wikipedia:Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing)
(WikiProject AI Cleanup). Note it also carries two things Octopus has nowhere: voice
calibration from real writing samples, and a rewrite→audit→rewrite double pass. One
overlap already exists — `substance-voice.md`'s "Never fabricate a number" is the
no-fabrication rule._

### RM-167 — `_shared/human-voice.md` + an anti-tell class in `substance-lint`

- **Priority:** 🔴 High
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-08-02

Add a sibling fragment to `substance-voice.md` covering the second axis, and extend the
lint with a second pattern class. Leave the existing anti-hype rules untouched — that
axis is solved; this one is missing.

Fragment scope — the subset of the 33 that actually bites in product copy: significance
inflation (`testament`, `pivotal`, `marks a shift`), copula avoidance (`serves as`,
`stands as`, `boasts`), negative parallelism (`not just X, it's Y`), superficial `-ing`
tails (`underscoring`, `highlighting`, `fostering`), bold inline-header lists, AI
vocabulary (`Additionally`, `delve`, `intricate`, `landscape`, `leverage`), and generic
positive conclusions.

`substance-lint.sh` already has the scan mechanics, `--strict`, and file:line reporting
— what is missing is the second `PATTERN`. These constructions are as regex-detectable
as hype: `testament|pivotal|serves as|underscor|delve|intricate|Additionally,|not just
.* it.s|Despite these challenges|future looks bright`. Report the two classes under
separate labels so a hype hit and a tell hit stay distinguishable.

**Rationale:** The gate that exists cannot see the problem being reported. Everything
else in this cluster is downstream of having a rule to point at.

### RM-168 — Stop the templates from hardcoding the tells

- **Priority:** 🔴 High
- **Effort:** low
- **Status:** proposed
- **Added:** 2026-08-02

The rule of three is not the model drifting — the **form requires it**. Every
LinkedIn post ships exactly three bullets, every Instagram caption exactly three
values, every landing page exactly three:

| File | Line |
|---|---|
| `skills/launch-feature/templates/channels/instagram.md` | 19 — `✔ {{VALUE_3}}` |
| `skills/launch-feature/templates/channels/linkedin.md` | 19 — `- {{POINT_3}}` |
| `skills/launch-feature/templates/channels/landing-copy.md` | 21 — `- {{BULLET_3}}` |
| `skills/launch-feature/templates/caption-templates.md` | 14, 31 |

Replace the fixed slots with a variable count (`{{POINTS_2_TO_4}}`) plus an instruction
to vary it per post, and drop the hardcoded `✔` decoration
(`instagram.md:17-19`, `caption-templates.md:12-14` — pattern 17, emoji).

Also loosen the single skeleton. `templates/voice.md` prescribes
Hook → Context → Mechanism → Outcome → CTA for *every* post, and
`channels/x.md` fixes 8 tweets with an assigned role each. Even with every sentence
clean, uniform structure across every channel and every launch reads as machine
cadence — the "soulless writing" failure, distinct from any individual pattern. Allow a
post to open on the number, on the objection, or on a flat sentence.

**Rationale:** Highest impact for the effort in this cluster. No prompt-level guidance
can avoid a pattern the form mandates, so this has to be fixed in the templates before
any rule about it can hold.

### RM-169 — Anti-tell audit pass before a launch kit closes

- **Priority:** 🟡 Medium
- **Effort:** low
- **Status:** proposed
- **Added:** 2026-08-02

`launch-release` already runs a pre-publish self-check, but it checks *substance*.
Add the humanizer's audit step to both launch skills: after the copy is drafted, ask
the literal question — "what makes this obviously AI-generated?" — answer it briefly,
then revise. The single-pass rewrite is what leaves the tells in; the value of the
double pass is that the second look is adversarial rather than generative.

Depends on RM-167 for the vocabulary to audit against.

**Rationale:** Rules catch what an author remembers to check. An explicit audit prompt
catches what they do not.

---

### Cluster 31 — Review-engine parity (deterministic detection layer)

_Proposed (added 2026-08-03). Comparison against
[alibaba/open-code-review](https://github.com/alibaba/open-code-review) (Apache-2.0, a Go
CLI derived from an internal reviewer that served thousands of engineers for two years).
The split is clean and worth stating before the items: Octopus is ahead on **review
governance** — roles with merge authority (`architect`/`dba`/`security`), the data-layer
dual gate, BLOCKING-vs-ADVISORY, domain routing into business risk (`audit-money`,
`audit-tenant`, `audit-contracts`), model tiering, and the fact that review sits inside a
lifecycle (dev-flow → commit → pr-open → release). OCR only emits comments; it decides
nothing. But it is ahead on the **detection engine**, and every item below is from that
side._

_The root difference: their determinism is compiled, ours is prose.
`skills/_shared/audit-pre-pass.md` and `audit-cache.md` describe file selection and
caching as protocols the model is asked to follow; OCR does the same work in code, before
any model call. Everything downstream — position accuracy, false-positive filtering,
bundling, rule matching — follows from that._

_Estimates below are order-of-magnitude, not measured. "Added tokens" is per review run,
relative to a current mid-size fan-out (~30–60k tokens); "Runtime" is added wall-clock per
run; "Effort" is implementation, in person-days for one engineer with an agent._

| RM | Item | Effort | Added tokens | Runtime | External dep |
|----|------|--------|--------------|---------|--------------|
| RM-170 | Anchor verification — every finding's `path:line` proven against the diff | low (1–2d) | ~0 (bash); net negative | +2–5s | none |
| RM-171 | Reflection pass — adversarial false-positive filter before the report is emitted | medium (2–4d) | +10–20% (~4–8k) | +20–60s | none |
| RM-172 | Compile the pre-pass and cache protocols into `cli/lib/` | medium (3–5d) | **−8–15%** (~1.2k/audit) | −5–15s | none |
| RM-173 | Size-based bundling inside the domain fan-out | medium (4–6d) | +5% overhead, unblocks large diffs | −30–50% wall-clock on big diffs | none |
| RM-174 | Data-driven rule catalogue, matched by path and language | high (8–12d) | **−10–25%** once rules replace prose | neutral | rule seed corpus (licence check) |
| RM-175 | Review evaluation harness with annotated ground truth | high (10–15d + ongoing) | n/a per review; ~500k–2M per bench round | hours per round | **yes** — annotated PR corpus, API budget |
| RM-176 | Persist review sessions; `--json` and `--severity` output | medium (3–4d) | ~0 | ~0 | none |
| RM-177 | Headless review in CI (GitHub Action) | high (6–10d) | +1 full review per PR | 3–10 min/PR | **yes** — API key, billing, repo secrets |
| RM-178 | Full-file scan mode (no git history) | medium (4–6d) | **very high** (repo-scale) | 10–40 min | none |

Dependency order: RM-170 → RM-171 (a reflection pass that cannot trust its own anchors is
filtering noise with noise). RM-175 gates the value of RM-171 and RM-174 — without
measurement, a precision change is a belief. RM-172 is independent and should go first on
cost grounds alone.

### RM-170 — Anchor verification for review findings

- **Priority:** 🔴 High
- **Effort:** low
- **Status:** proposed
- **Added:** 2026-08-03

Every finding in a `codereview` / `pr-review` report cites `path:line`, and that citation
is written from the model's head — nothing checks it. OCR treats this as a first-class
failure mode ("position drift") and ships an **external positioning module** that resolves
the location outside the agent.

Deterministic version for Octopus: after Phase 4 aggregation and before the report is
printed or posted, run each finding through a check — does the file exist at that ref, is
the line within the file's length, and does the line fall inside a hunk this diff actually
touched? A finding that fails demotes to QUESTION with `[origin: …] unanchored` rather
than being silently reported at the wrong place. Reuse the diff already computed in
Phase 1; no second `git diff`.

- **Token cost:** none — pure bash over the report and the cached diff. Net negative in
  practice, since a demoted finding stops generating follow-up reads.
- **Runtime:** +2–5s per review.
- **External deps:** none (`git`, `awk`).

**Benefits:**

- **Reviewer time back.** A reviewer who opens the wrong file to check a finding pays
  the full cost of a real finding for nothing. This is the most common way review
  output wastes a senior's afternoon.
- **Unblocks inline PR comments.** Posting a finding on its line
  (`gh api .../comments` with `line` + `side`) requires an anchor the API will accept —
  today a bad line number is a failed API call or a comment on unrelated code, so
  `pr-review` can only post one aggregated blob. With anchors proven, per-finding inline
  comments become safe to ship.
- **Turns a hallucination into a labelled one.** An invented location currently arrives
  indistinguishable from a real one. `unanchored` makes the failure legible instead of
  plausible.
- **Makes automatic scoring possible.** RM-175 can only count a hit if the finding lands
  on the annotated line; without anchors, every benchmark run needs a human to adjudicate
  matches.

**Rationale:** A wrong line number is the most visible failure a reviewer can produce and
the cheapest to prevent. It also gates RM-171 — filtering findings is meaningless while
the findings point at the wrong code.

### RM-171 — Reflection pass: filter false positives before emitting

- **Priority:** 🔴 High
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-08-03

OCR runs a **comment-reflection module** — a dedicated pass whose only job is to kill
false positives, and it is the mechanism behind their deliberate precision-over-recall
trade. Octopus has `audit-grounding` and `audit-verification`, but both are signal-only
and run *after* the fact; neither stands between a finding and the PR comment.

Add a Phase 4.5 between aggregation and report: each finding is re-read adversarially
against its anchored code (RM-170), with the burden of proof on the finding. Send the
findings plus their anchored hunks, **not** the whole diff — that is what keeps this
affordable. Run it on Sonnet (mechanical adjudication, not architecture). A finding that
does not survive is dropped with a one-line reason kept in the session record (RM-176), so
the filter is auditable rather than a black hole.

- **Token cost:** +10–20% of a review run (~4–8k on a mid-size diff), bounded by finding
  count rather than diff size.
- **Runtime:** +20–60s (one extra LLM call, parallelisable per finding).
- **External deps:** none.

**Benefits:**

- **Makes the Phase 5 commit block defensible.** `codereview` already blocks a commit on
  any open BLOCKING finding. A false BLOCKING therefore stops real work — and the fastest
  way to teach a team to bypass the gate is to block them wrongly once. Precision is a
  precondition for having an automated gate at all, not a refinement of one.
- **Lowers triage cost, which is where review actually gets abandoned.** Twelve findings
  where four are noise costs more than four findings, because every one must be read and
  dismissed by a human who cannot tell them apart in advance.
- **Auditable filtering.** The discard reason is recorded (RM-176), so an over-aggressive
  filter is visible and tunable rather than a silent hole in coverage.
- **Prerequisite for unattended review.** A CI reviewer (RM-177) with a high false-positive
  rate gets muted within two weeks, and then the spend continues with the value gone.

**Rationale:** Reviewer trust is spent by the first confident wrong finding, not earned by
the tenth right one. Depends on RM-170; its value is unprovable without RM-175.

### RM-172 — Compile the pre-pass and cache protocols into `cli/lib/`

- **Priority:** 🔴 High
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-08-03

`skills/_shared/audit-pre-pass.md` (41 lines) and `audit-cache.md` (52 lines) are loaded
into every dispatched `audit-*` sub-agent and describe work that is entirely mechanical:
`git diff --name-only | grep -E <pattern>`, an early exit, a line filter, a
`sha256sum`-keyed cache lookup. The model is asked to run them faithfully every time. OCR
does the equivalent in a binary — file selection and bundling are guaranteed, not
requested.

Move both into `cli/lib/` as executable steps that read `pre_pass.file_patterns`,
`pre_pass.line_patterns` and the skill hash from the frontmatter the skills already
declare, and hand the sub-agent a scoped diff plus a cache verdict. The skills keep a
one-line reference instead of the protocol body. `cli/lib/audit-map.sh` and
`tests/test_audit_output_cache.sh` already establish the pattern and the contract.

- **Token cost:** **−8–15%** per review — roughly 1.2k tokens of protocol text saved per
  dispatched audit, plus the cache hits that currently depend on the model choosing to
  check.
- **Runtime:** −5–15s (bash beats a model reasoning about `grep`).
- **External deps:** none.

**Benefits:**

- **The cache stops being optional.** The saving from `audit-cache.md` today is conditional
  on the model choosing to compute the key and check the file. Compiled, a repeat review of
  an unchanged diff costs a `sha256sum` instead of a model call — the largest single
  saving in the cluster, and it applies to the re-review loop (fix, re-run) that happens
  several times per PR.
- **Early exit becomes guaranteed.** A dispatched audit whose domain has no matching files
  should cost nothing. Today it costs a sub-agent spin-up plus the protocol read before the
  model concludes there is nothing to do.
- **One place to change.** Protocol edits currently have to hold across every skill that
  embeds them, with drift invisible until an audit behaves differently from its siblings.
- **Testable as behaviour.** `tests/test_audit_output_cache.sh` can assert what the code
  does; against prose it can only assert that the text still says it.

**Rationale:** The cheapest item in the cluster and the only one that pays for itself
immediately. It also converts "the pre-pass usually runs" into "the pre-pass ran".

### RM-173 — Size-based bundling inside the domain fan-out

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-08-03

The Phase 1 matrix fans out by **risk domain** — better than OCR on that axis, since it
routes to business risk no generic ruleset detects. But it does not fan out by **size**: a
400-file change that matches only `audit-tenant` goes to a single sub-agent, and the
Phase 0 size gate only decides single-pass vs fan-out, never how wide the fan-out is.

OCR's answer is bundling — group related files into review units, one isolated sub-agent
each, concurrent. Port the second half of that: after the domain match, if a domain's file
subset exceeds a threshold (~40 files or ~2k changed lines), split it into bundles grouped
by directory proximity and shared imports, dispatch one sub-agent per bundle, and merge
their findings under the same origin before Phase 4.

- **Token cost:** +~5% coordination overhead; the real effect is making large reviews
  possible at all instead of degrading silently near the context limit.
- **Runtime:** −30–50% wall-clock on large diffs (concurrency), unchanged on small ones.
- **External deps:** none.

**Benefits:**

- **Removes a silent failure mode.** A domain subset that overflows the context window does
  not error — it produces a shorter report. The review looks like it passed. This is the
  worst class of bug a quality gate can have, and it fires precisely on the migrations,
  refactors and vendor bumps that carry the most risk.
- **Coverage becomes reportable.** Bundles make "which files were actually reviewed" a
  known list, so a partial review can say so instead of implying completeness.
- **Large PRs re-enter the normal loop.** A 20-minute serial review gets deferred; a
  6-minute concurrent one gets run.
- **Keeps the domain routing intact.** This adds a second axis under the existing risk
  matrix rather than replacing it with OCR's generic file grouping — the domain skills
  (`audit-money`, `audit-tenant`) still see their own files, just in shards.

**Rationale:** Today a big single-domain PR gets the worst review, which is exactly
backwards from the risk it carries.

### RM-174 — Data-driven rule catalogue matched by path and language

- **Priority:** 🟡 Medium
- **Effort:** high
- **Status:** proposed
- **Added:** 2026-08-03

Octopus rules live as prose inside each `audit-*` SKILL.md. Adding a check means editing
or authoring a skill, and every check in a skill is loaded whether or not the diff can
trigger it. OCR ships a rule catalogue — NPE, thread-safety, XSS, SQL injection across 10+
languages — matched to each file by a template engine with path filtering, so only
applicable rules enter the prompt, and a custom rule is a config entry.

Scope for Octopus: a `rules/catalogue/<language>.yml` format (id, language, path glob,
detection hint, severity, example), a matcher in `cli/lib/` that resolves the applicable
set per file, and injection of only those rules into the sub-agent. The existing
`triggers`/`pre_pass` frontmatter is the precedent for path-based selection.

- **Token cost:** **−10–25%** at steady state — matched rules are shorter than the prose
  they replace and scale with the diff instead of the catalogue. Transitional cost while
  both forms coexist.
- **Runtime:** neutral.
- **External deps:** seeding from a public ruleset (OCR's own is Apache-2.0; Semgrep
  community rules are LGPL-2.1) needs a licence and attribution review before any import.
  Authoring from scratch has no dependency.

**Benefits:**

- **The team can extend review without authoring skills.** This is the manager-multiplier
  payoff (Cluster 16): an engineer who just debugged a production incident can add the rule
  that would have caught it, as a YAML entry, in the same PR as the fix. Today that
  requires learning the skill format and touching a shared skill body — a barrier high
  enough that the rule usually never gets written.
- **Rules become fleet assets.** A rule is data, so it can be diffed, reviewed, versioned,
  and distributed across repos by `fleet-bootstrap` — with `audit-fleet` reporting which
  repos are missing which rules. Prose inside a skill cannot be distributed selectively.
- **Cost scales with the diff, not the catalogue.** Adding the 200th rule costs nothing on
  a diff that does not match it. Today every check in a skill is loaded whether or not it
  can fire, which caps how large the catalogue can get.
- **Language coverage without skill sprawl.** New-language support becomes a catalogue
  file rather than a new audit skill or another `cli/lib/adapter-*.sh`.
- **Rules gain provenance.** id, severity and example per rule means a finding can cite
  *which* rule it violated — which is what makes a finding teachable (the `mentor` role)
  instead of merely correct.

**Rationale:** Turns "a new check requires a skill author" into "a new check is a YAML
entry" — the difference between a catalogue the team extends and one only its maintainer
touches.

### RM-175 — Review evaluation harness with annotated ground truth

- **Priority:** 🔴 High
- **Effort:** high
- **Status:** proposed
- **Added:** 2026-08-03

This is the item that makes the others measurable, and the one Octopus most conspicuously
lacks. OCR publishes a benchmark — 50 repos, 200 PRs, 10 languages, 1,505 validated issues
— and reports precision, recall, F1 and token consumption against general-purpose agents.
Octopus `tests/` covers routing, caching, bundles and tiering: mechanics, never accuracy.
Every prompt change to an `audit-*` today is an act of faith.

Build a corpus of PRs with human-annotated findings (start small — 20–30 PRs across the
stacks actually in use), a runner that executes the review pipeline against each at a
pinned ref, and a scorer reporting precision / recall / F1 / tokens per run. Anchor
matching (RM-170) is what makes automatic scoring possible — a finding counts as a hit
only if it lands on the annotated line.

- **Token cost:** not per-review. ~500k–2M output tokens per full benchmark round
  depending on corpus size; run per release, not per PR.
- **Runtime:** hours per round, unattended.
- **External deps:** **yes, and this is the real cost** — the annotated corpus needs human
  judgement (est. 15–25h for the initial set) and cannot be generated by the system under
  test. Plus API budget for the rounds. Public repos avoid any licensing question; using
  internal PRs does not.

**Benefits:**

- **Ends prompt tuning by opinion.** Every change to an `audit-*` body currently ships on
  the author's judgement. With a scorer, a change that sounds better but reviews worse is
  caught before release rather than absorbed silently.
- **Regression protection for quality.** Skill edits, model swaps and the compression pass
  (`compress-skill`) can each quietly degrade detection. Mechanics tests will not notice.
  This is the only thing that would.
- **Proves the savings are free.** RM-172 and RM-174 claim double-digit token cuts. Measured
  alongside F1, the harness distinguishes "cheaper" from "cheaper because it stopped
  looking" — which is otherwise indistinguishable from the outside.
- **Model tiering by evidence.** RM-130 and RM-160 assigned Haiku/Sonnet/Opus by reasoning
  about the work each skill does. A benchmark answers it empirically, and may well show
  some domain audits run fine a tier lower.
- **A number to show.** For fleet adoption, "our reviewer finds X% of known issues" is an
  argument other teams can evaluate; "our reviewer is good" is not.

**Rationale:** Without this, every claim about review quality — including the ones in this
cluster — is unfalsifiable. It is the difference between tuning and guessing.

### RM-176 — Persist review sessions; machine-readable output

- **Priority:** 🟡 Medium
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-08-03

A Octopus review report is ephemeral: printed to the user or posted as a PR comment, then
gone. OCR persists sessions — `session list`, `--resume` for an interrupted run,
`session comments --severity critical,high --json`, and a browser replay viewer.

Minimum useful version: write each run to `.octopus/reviews/<ref>-<timestamp>.json`
(findings with origin, severity, anchor, verdict, and the reflection reason from RM-171),
a `--json` flag on `codereview`/`pr-review`, and `--severity` filtering. `--resume` for an
interrupted fan-out follows from the same record. Skip the browser viewer. The
`.octopus/cache/` gitignore guard is the precedent for placement.

- **Token cost:** ~0 (serialisation of data the run already produced).
- **Runtime:** ~0.
- **External deps:** none.

**Benefits:**

- **An interrupted review stops being a total loss.** A large fan-out that dies partway
  through today discards every completed sub-agent's work — the user pays the full cost
  again. `--resume` recovers it.
- **Review output becomes queryable.** `--json` + `--severity` is what lets anything
  downstream consume findings: a CI gate (RM-177), the RM-175 scorer, or a trend view
  alongside `code-metrics`.
- **Trends, not snapshots.** With runs on disk, "are the same findings recurring across
  PRs?" becomes answerable — which is where a manager learns what to teach, versus what to
  fix once.
- **Best cost-to-value ratio in the cluster.** Roughly zero token and runtime cost, and
  three other items are gated on it.

**Rationale:** Prerequisite for anything that consumes review output — the RM-175 scorer,
CI gating in RM-177, and trend tracking alongside `code-metrics` — none of which can read
a report that was never written down.

### RM-177 — Headless review in CI

- **Priority:** 🟡 Medium
- **Effort:** high
- **Status:** proposed
- **Added:** 2026-08-03

Octopus review requires a human driving an interactive agent. `.github/workflows/` carries
only `build-release.yml` and `pages.yml`. OCR runs headless in GitHub Actions, GitLab CI,
Gerrit and GitFlic, with OpenTelemetry for observability — review happens whether or not
anyone remembers to ask for it.

Ship a reusable GitHub Action that runs the review pipeline against a PR diff, posts the
aggregated report as a PR comment (already the `pr-review` Phase 5 format, signature
included), and optionally fails the check on BLOCKING/CRITICAL. Requires RM-176 for the
machine-readable output the step gates on. Given the fleet framing (`audit-fleet`,
`fleet-bootstrap`), the Action should be consumable per-repo from one pinned source, the
same delivery model the release Action already uses.

- **Token cost:** high and recurring — one full review per PR, unattended. On a 6-repo
  fleet this is the single largest ongoing spend in the cluster; RM-172 and RM-174 should
  land first to lower the unit cost.
- **Runtime:** 3–10 min per PR.
- **External deps:** **yes** — an API key with billing attached, repo/org secrets, and
  `pull-requests: write` on the workflow token. Fork PRs need the usual
  `pull_request_target` handling and a secret-exposure review.

**Benefits:**

- **Review stops depending on discipline.** Every other item improves a review someone
  chose to run. Across 6+ repos, the reviews that matter most are the ones nobody
  remembered to run — a rushed hotfix on a Friday is exactly the diff that skips
  `/octopus:codereview`.
- **A uniform floor across the fleet.** Repos at different adoption tiers currently get
  different review quality by accident. An Action pinned from one source gives every repo
  the same baseline regardless of who is working in it.
- **Human reviewers start from a cleaner diff.** The debug statement, the missing tenant
  filter and the TODO are already flagged when the human opens the PR, so their attention
  goes to design — the part no checklist covers.
- **Consistency between local and CI.** Reusing the `pr-review` Phase 5 report format and
  signature means CI does not become a second, divergent reviewer with its own opinions.
- **Adoption becomes measurable.** With RM-176, findings per repo over time feed
  `audit-fleet` — showing where standards are actually landing rather than where they
  were configured.

**Rationale:** Everything else in the cluster improves a review someone chose to run. This
is the one that makes review unconditional — and the one with a standing bill, which is
why it is Medium and sequenced last.

### RM-178 — Full-file scan mode (no git history)

- **Priority:** 🟢 Low
- **Effort:** medium
- **Status:** proposed
- **Added:** 2026-08-03

Every `audit-*` is diff-centric: the pre-pass starts from `git diff --name-only`, so an
audit of an unfamiliar codebase with no relevant recent changes finds nothing. OCR ships
`ocr scan [--path]` for exactly this — full-file review for auditing a repo you have just
inherited. Octopus has `map-system` (structure) and `code-metrics` (health signal), but no
defect scan over existing code.

Add a `--scan <path>` mode that feeds the same audit skills a file set from a path walk
instead of a diff. Unbounded scanning is the trap, so the mode must ship with
prioritisation — highest-risk paths first (the `audit-map.sh` domains), a file budget, and
resumability via RM-176 — and report explicitly what it did not cover.

- **Token cost:** **very high** — scales with repo size, not change size; easily 10–50×
  a diff review. Only viable with a hard budget and a stated coverage report.
- **Runtime:** 10–40 min for a mid-size repo.
- **External deps:** none.

**Benefits:**

- **Covers the case where the diff tells you nothing.** Inheriting a repo, taking over a
  service, or auditing a vendor drop — the risk is entirely in code nobody is currently
  changing, which every `audit-*` is structurally blind to.
- **Completes the onboarding story.** `map-system` explains the structure and
  `code-metrics` reports health; neither says "here are the defects". A new owner
  (or a new team member) gets the third piece.
- **Produces a debt baseline.** One scan establishes the inventory; the diff-mode reviews
  then keep it from growing. Without a baseline, "is this repo getting better?" has no
  starting point.
- **Reuses everything else.** It is a different file-selection front end on the same
  skills, rules (RM-174) and reflection pass (RM-171) — so it inherits their quality
  rather than needing its own.

**Rationale:** Fits the manager-multiplier framing (Cluster 16) — inheriting a repo is
when a defect scan is worth most. Lowest priority because it is the only item here that
does not improve the reviews already being run, and the most expensive to run casually.
