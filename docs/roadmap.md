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

_Proposed (added 2026-06-03). Seeds from [research](research/2026-06-03-token-cost-optimization.md): a measured pass over the always-loaded surface and the fan-out orchestrators. The baseline is **~8.4k tokens/session/repo** (`.claude/CLAUDE.md` ~14.5 KB + `rules/common/*` ~19.2 KB) with **confirmed duplication** — `core/guidelines.md` (inlined into the generated CLAUDE.md as `{{CORE}}`) repeats Principles/Security/Testing already expanded in `rules/common/*`. At ~30 sessions/day × 6 repos that is ~7.5M tokens/month of cold re-injection. Governing fact: `.claude/CLAUDE.md` is **generated** by `setup.sh::generate_from_template()` from the `agents/claude/CLAUDE.md` template + `core/*.md`, so every fix edits the **source** and regenerates, never the generated file. Decision: **aggressive** (full progressive disclosure + lang-split + model tiering), shipped as the **baseline default for all repos**. Deepens Clusters 1 (RM-022) & 2 (RM-025/026), which closed individual wins. Build order: RM-131 (measurement) first → Item-1 baseline (RM-117→121) → orchestrators (RM-122→126) → registry/tiering (RM-127→130)._

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
| RM-130 | Global model tiering — cheap-tier (Sonnet/Haiku) for `audit-*` skills + non-`architect` roles, reserve Opus for `architect`/`dba`/code; add `model:` to skills + enforcement (`.octopus.yml` + `.claude/agents/` delivery). Biggest **$** multiplier on the 6-agent fan-out | cross-cutting |
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
