# Research — Token-cost optimization (max usage efficiency)

- **Date:** 2026-06-03
- **Author:** Leonardo (Tech Manager II, ex-Staff SWE)
- **Roadmap:** seeds **Cluster 23** (RM-117 … RM-131)
- **Trigger:** A question — "which Octopus routines automatically invoke LLM
  analysis indirectly (via frontmatter or hooks)?" — turned into a cost question:
  what are the main token offenders, and how do we cut them. Measuring the
  always-loaded context surfaced confirmed duplication and a fleet-wide multiplier
  (Octopus serves 6+ repos), making this a structural optimization, not a one-off.

> **Relation to Clusters 1 & 2.** Cluster 1 ("Reduce tokens loaded per session",
> RM-022) and Cluster 2 ("Reduce LLM calls", RM-025/026) closed individual wins.
> This is a deeper, measured pass over the *whole* always-loaded surface and the
> fan-out orchestrators, shipping a new baseline default for the fleet.

---

## The cost surface — measured

Bytes measured in-repo; tokens at ~4 chars/token.

### Always loaded, every session, every repo (~8.4k tokens)

| Source | Bytes | ~Tokens |
|---|---|---|
| `.claude/CLAUDE.md` (generated) | 14,497 | ~3,600 |
| `rules/common/*.md` (7 files, symlinked) | 19,159 | ~4,800 |
| └ `exceptions.md` alone | 9,316 | ~2,300 |
| **Baseline per session** | **~33.6 KB** | **~8,400** |

Plus the registry listing (61 skills + 45 commands + 11 roles `description:`
frontmatter) ≈ **4–5k tokens/session**.

**Projection:** at ~30 sessions/day across 6 repos, the ~8.4k baseline alone is
**~250k input tokens/day ≈ ~7.5M/month** of cold re-injection (prompt cache only
helps *within* a session; each new session reloads cold).

### How the baseline is assembled (governs every fix below)

- `.claude/CLAUDE.md` is **generated** by `setup.sh::generate_from_template()`
  from the template `agents/claude/CLAUDE.md` (placeholders `{{CORE}}`,
  `{{RULES}}`, `{{SKILLS}}`).
  - `{{CORE}}` ← **inline** concatenation of 5 `core/*.md` files (`guidelines`,
    `architecture`, `commit-conventions`, `pr-workflow`, `task-management`).
  - `{{RULES}}` / `{{SKILLS}}` ← reference lines only ("See .claude/rules/… for…").
- `rules/common/*.md` are **symlinked** into `.claude/rules/` and loaded via
  `native_rules: true` (`agents/claude/manifest.yml`).
- **Therefore the fix edits the source** (`core/`, the template, `rules/`,
  `manifest.yml`, `setup.sh`) and **regenerates** — never the generated
  `.claude/CLAUDE.md` (it is overwritten).

### Confirmed duplication (loads 2× every session)

`core/guidelines.md` (inlined into CLAUDE.md as `{{CORE}}`) repeats content that
already lives, expanded, in `rules/common/*` (symlinked, always loaded):

| Duplicated block | In CLAUDE.md via | Canonical home |
|---|---|---|
| Principles (KISS/DRY/YAGNI), Code Structure, Anti-Patterns | `core/guidelines.md` | `rules/common/coding-style.md` |
| Security bullets | `core/guidelines.md` | `rules/common/security.md` (expanded) |
| Testing bullets | `core/guidelines.md` | `rules/common/testing.md` (expanded) |

`rules/{csharp,python,typescript}/` already exist (8/5/7 files), so a
**load-only-the-stack** split is ready to wire — today every repo loads all of
`rules/common` regardless of language.

## The five offenders and their levers

| # | Offender | When | Level | Lever (RM) |
|---|---|---|---|---|
| 1 | Always-loaded baseline | automatic, every session | 🔴 High | dedup (RM-117), exceptions on-demand (RM-118), thin CLAUDE.md (RM-119), lang-split (RM-120), compress (RM-121) |
| 2 | `pr-review` / `codereview` fan-out | on demand | 🔴 High (burst) | subset routing (RM-122), gated dispatch (RM-123), single-pass small PR (RM-124) |
| 3 | `audit-all` (4 parallel) | on demand | 🟠 Med-high | triggers-matched default + SHA memo (RM-125) |
| 4 | `dev-flow` chain | on demand | 🟠 Med-high | expensive steps opt-in (RM-126) |
| 5 | Registry (~117 items) | automatic, every session | 🟠 Med | bundle-per-stack (RM-127), trim descriptions (RM-128), consolidate families (RM-129) |
| × | Cross-cutting | — | — | model tiering (RM-130), measurement harness (RM-131) |

Note: the Stop hooks (`grounding-check`, `verification-check`,
`propose-knowledge-update`, `review-log-capture`) are **zero-LLM by contract** —
they only queue proposals; their cost is deferred to `review-proposals` /
`continuous-learning`. Not an offender by themselves; out of scope here.

---

## Items

### RM-117 — Dedup `core/guidelines.md` ↔ `rules/common/*`

**Need:** stop loading Principles/KISS/DRY/Anti-Patterns/Security/Testing twice.
Rewrite `core/guidelines.md` to *reference* `rules/common/{coding-style,security,
testing}.md` (the canonical, expanded versions) instead of repeating them, so the
inlined `{{CORE}}` shrinks. Regenerate via `setup.sh`.

**Problem it solves:** ~1.5k tokens of pure duplicate loaded every session, every
repo. Zero coverage loss — the canonical copy stays. Lowest-risk first step.

### RM-118 — Move `exceptions.md` (9.3 KB) to on-demand

**Need:** the G1–G4 gate + per-language C#/Python/TS worked examples (2.3k tokens)
only matter when introducing `class XException` / `raise` / `throw new`. Move it
out of always-loaded `rules/common` into a skill/`REFERENCE.md` (candidate: attach
to `audit-style`, RM-112, which already encodes the gate) triggered on those
patterns.

**Problem it solves:** the single fattest always-loaded file (~28% of the rules
budget) is relevant to a tiny fraction of sessions. On-demand loading recovers it
for the rest.

### RM-119 — Thin CLAUDE.md: reference material out of inline `{{CORE}}`

**Need:** `commit-conventions`, `pr-workflow`, `task-management`, `architecture`
are reference material that rarely matters mid-session but is inlined into every
CLAUDE.md. Stop inlining them in `{{CORE}}`; load on-demand from the commands that
use them (`commit`, `pr-open`, `triage-issues`, `doc-adr`) or via `REFERENCE.md`.
Adjust `setup.sh::generate_from_template()` (`CORE_FILES`) and the template.

**Problem it solves:** ~2–3k tokens/session of conventions that the relevant
commands can pull when actually needed. Target: generated CLAUDE.md ~14.5 KB → ~3–4 KB.

### RM-120 — Lang-split rules loading (load only the stack)

**Need:** load `rules/<stack>/**` + a minimal `common` per repo instead of all of
`rules/common`. Wire a stack profile through `.octopus.yml`/bundles and
`setup.sh::deliver_rules`; reuse the existing `rules/{csharp,python,typescript}/`
trees and the package-manager detection already in `load-context.sh`.

**Problem it solves:** a Python repo loads C#/TS-flavored guidance it never uses.
Per-stack delivery cuts the rules budget in mono-stack repos (the common case).

### RM-121 — Compress remaining `rules/common` to canonical dense form

**Need:** run the deterministic `compress-skill` pass + `context-budget` over the
post-dedup `rules/common` to remove filler without changing meaning.

**Problem it solves:** residual verbosity after RM-117/119 still loads every
session. ~15–25% off the remaining block. Reuses existing tooling.

### RM-122 — Subset-route the review fan-out (don't send the full diff to all 6)

**Need:** `codereview`/`pr-review` dispatch up to 6 agents (architect, dba,
security + audit-security/money/tenant/contracts), each reading the **whole** diff
= 6× the diff tokens. Route each audit/role only its domain-matching file subset,
mirroring `skills/audit-all` and `skills/_shared/audit-output-format.md`.

**Problem it solves:** the dominant cost in a review is the diff read N times.
Subsetting cuts ~40–60% of diff tokens with minimal coverage loss.

### RM-123 — Gate the dispatch on the zero-LLM audit map

**Need:** feed the `cli/lib/audit-map.sh` output (already used by
`pre-push-audit-suggest`, deterministic) into `codereview`/`pr-review` so it
dispatches **only matched** audits; make `architect` conditional on diff size/risk
instead of always-on.

**Problem it solves:** today the review fires fixed roles/audits regardless of what
the diff touches. Gating skips 2–4 agents on a typical PR.

### RM-124 — Single-pass review for small PRs

**Need:** below ~150 changed lines, run one consolidated reviewer (diff read once)
instead of the multi-agent fan-out.

**Problem it solves:** fan-out overhead dominates on small PRs where specialization
adds little. ~80% saving in that band.

### RM-125 — `audit-all`: triggers-matched default + SHA memoization

**Need:** default `audit-all` to only the audits whose `triggers` match the diff
(not the fixed 4), and skip re-auditing a ref already audited (memoize by SHA,
reusing `skills/_shared/audit-cache.md`).

**Problem it solves:** the composer runs all 4 even when one domain changed, and
re-runs cost full price on unchanged refs.

### RM-126 — `dev-flow`: expensive steps opt-in

**Need:** make the self-review (Step 3) and release (Step 6) opt-in, and run
self-review only pre-merge rather than on every iteration.

**Problem it solves:** the orchestrator currently re-triggers the review burst on
each pass. Opt-in stops paying for steps not wanted that run.

### RM-127 — Bundle-per-stack delivery (prune the registry per repo)

**Need:** deliver only the skills/roles the repo's stack needs — a backend repo
should not list frontend/vercel/launch-* in its session registry. Reuse `bundles/`
+ `setup.sh::expand_bundles`/`deliver_skills`.

**Problem it solves:** the full ~117-item registry (~4–5k tokens) is listed every
session even when most items can never apply to the repo. Per-stack pruning trims
the listing to what's reachable.

### RM-128 — Trim `description:` frontmatter across the registry

**Need:** the `description:` of each skill/command is what the session registry
lists. Tighten ~117 of them to one dense line.

**Problem it solves:** ~10 tokens × 117 items ≈ ~1k tokens/session of listing prose.

### RM-129 — Consolidate families + remove skill↔command redundancy

**Need:** collapse `audit-*` / `doc-*` / `knowledge-*` into fewer top-level
entries where they are sub-modes, and remove items duplicated as both a `skills/`
and a `commands/` entry.

**Problem it solves:** fewer registry entries to list every session, and less
maintenance drift between duplicated skill/command pairs.

### RM-130 — Global model tiering (cheap-tier for audits/non-architect roles)

**Need:** assign cheap-tier (Sonnet/Haiku) to the `audit-*` skills and
non-`architect` roles; reserve Opus for `architect`/`dba`/code. Roles already
carry `model:` frontmatter; add tier to skills + an enforcement path
(`.octopus.yml` + delivery in `.claude/agents/`).

**Problem it solves:** a review fan-out runs ~6 agents — tiering them off Opus is
the single biggest **$** multiplier without losing much depth (audit-verification
is already cheap-tier).

### RM-131 — Measurement harness + CI budget check

**Need:** extend `skills/context-budget` to emit a token report (CLAUDE.md, each
`rules/**`, registry-description sum, always-loaded total) and add a
`tests/test_context_budget.sh` that fails if the baseline exceeds a ceiling (e.g.
CLAUDE.md > 4 KB; any core↔rules duplication).

**Problem it solves:** without a guardrail the baseline silently regrows. This
turns the optimization into an enforced budget across the fleet and provides the
before/after numbers for every other RM here. Build first.

## Discarded Items

| Item | Reason |
|---|---|
| Disable the Stop hooks to save tokens | They are zero-LLM (bash); they cost nothing per se. Disabling saves no tokens and removes signal. Their deferred cost belongs to `review-proposals`, governed separately. |
| Make the optimizations opt-in per repo | Decision was baseline-for-all (max efficiency across the fleet). Opt-in would slow adoption; safety is handled by the RM-131 budget check + cross-stack verification instead. |
| Drop prompt caching reliance / restructure for cache hits | Cache helps within a session only; the win here is shrinking the cold baseline. Cache-alignment is a minor follow-up, not a roadmap item. |
| Lazy registry discovery (don't pre-list skills) | Depends on harness support outside Octopus's control. RM-127/128/129 reduce the listing within what Octopus owns. |
