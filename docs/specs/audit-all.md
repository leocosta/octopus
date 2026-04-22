# Spec: Audit-All

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-19 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **RFC** | N/A |
| **Roadmap** | RM-028 |

## Problem Statement

Octopus ships four audit skills that all target a git diff:
`security-scan`, `money-review`, `tenant-scope-audit`, and
`cross-stack-contract`. Running a full pre-merge review today means
invoking each of them sequentially, and each one repeats the same
preparatory work: resolve the ref, compute the diff, list touched
files, classify them by domain. Four sequential invocations also
stack latency — the user waits for each one to finish before the
next starts.

On top of that, the `quality-gates` bundle currently enumerates every
audit skill individually, so adding a new audit means updating both
the bundle and its tutorial. New users see a list of four skills and
aren't sure whether they're supposed to run them one-by-one or
somehow together.

## Goals

- Ship a new skill `octopus:audit-all` that runs the four existing
  audit skills in parallel, with a shared file-discovery pass, and
  produces one consolidated severity report.
- Introduce a generic `depends_on:` field in skill frontmatter so
  one skill can declare it pulls other skills. The bundle-expansion
  code resolves the dependency graph at setup time; bundles gain a
  concise "composer skill" pattern that hides the dependency list.
- Update `bundles/quality-gates.yml` to list `audit-all` instead of
  the four individual audits; the `depends_on:` resolver arranges
  for the individual skills to still ship so users who want focused
  runs (just `money-review`, say) keep that path.
- Preserve the exact output format and confidence labels already
  used by the audit skills so the concatenated report is identical
  in shape.

## Non-Goals

- Replacing the four audit skills. Individuals remain first-class
  and independently invocable.
- Caching results. RM-026 covers that separately.
- Pre-LLM grep pass for shared discovery. RM-025 covers that; here
  the discovery is whatever the agent already does, just consolidated
  into one pass.
- Changing the output format of the existing audits. `audit-all`
  only orchestrates and concatenates.
- A CI `--fail-on=block` flag. v1 is guidance; a future RM can wrap
  this into a gate.

## Design

### Overview

A pure-markdown skill `skills/audit-all/SKILL.md` + slash command +
`bundles/quality-gates.yml` rewrite + a small `expand_bundles`
extension in `setup.sh` for the `depends_on:` resolver. Same overall
architecture as every other Octopus skill.

The skill orchestrates in three phases:

1. **Shared file discovery.** Resolve `ref` → `base`, compute the
   diff once, classify each touched file into domain tags
   (`money`, `tenant`, `webhook`, `auth`, `api-contract`,
   `frontend-consumer`, `secrets`, `config`). Produce a map
   `{file: [domains]}` that the per-audit phase consumes.
2. **Parallel audit execution.** Dispatch four subagents in parallel
   using `superpowers:dispatching-parallel-agents`. Each subagent
   runs one audit skill against the subset of files matching its
   domain tags. No re-discovery per audit.
3. **Consolidated report.** Concatenate the four audit reports into
   one markdown block with a unified summary header and a cross-audit
   hotspots table (files that appear in ≥ 2 audits).

### Invocation

```
/octopus:audit-all [ref] [--base=main] [--only=<audits>] [--write-report]
```

- `ref` (optional): PR (`#123`/URL), branch, or commit SHA.
  Default: current `HEAD` vs upstream.
- `--base=<branch>`: default `main`.
- `--only=<list>`: comma-separated subset of
  `security,money,tenant,cross-stack`. Default: every audit whose
  skill is installed (see "Graceful degradation" below).
- `--write-report`: also persist to
  `docs/reviews/YYYY-MM-DD-audit-all-<slug>.md`.

### `depends_on:` frontmatter contract

Every skill's `SKILL.md` can optionally declare:

```yaml
---
name: audit-all
description: >
  Run all quality audit skills in parallel against a single ref,
  with shared file discovery and a consolidated report.
depends_on:
  - security-scan
  - money-review
  - tenant-scope-audit
  - cross-stack-contract
---
```

`setup.sh` gets a new function `_resolve_skill_dependencies()` called
from `expand_bundles()` after the existing bundle union. It walks
`OCTOPUS_SKILLS`, reads each skill's frontmatter (parsing only the
`depends_on:` block — lightweight grep, not a full YAML parser),
appends declared deps to `OCTOPUS_SKILLS`, and loops until no new
skills are added. Final `_dedupe_array OCTOPUS_SKILLS` keeps the
list clean.

Resolver rules:
- Missing dependency (declared in `depends_on` but no
  `skills/<name>/SKILL.md` exists) → warn and skip that dep. The
  parent skill still ships. This keeps installs working even when
  a dependency is renamed or removed.
- Cycles (`A depends_on B` and `B depends_on A`) → abort with
  "skill dependency cycle detected: A → B → A". No silent infinite
  loop.
- Depth limit: 5 levels. Deeper is almost certainly a bug; abort.

### Shared file discovery

The agent running `audit-all` executes a single discovery pass:

1. `git diff --name-only <base>...<ref>` → list of touched files.
2. For each file, apply the domain-tag heuristics from the four
   audits' patterns, already documented in their templates
   (`skills/money-review/templates/patterns.md`, etc.). The agent
   reuses those patterns — no duplication.
3. Produce `file → [domains]` map. Example:
   `api/src/.../BillingController.cs → [money, tenant, api-contract]`.

If the diff is empty, emit "audit-all: no changes to review" and
exit 0.

### Parallel audit execution

The agent dispatches four subagents via
`superpowers:dispatching-parallel-agents`, one per audit, each with:

- The subset of files tagged with that audit's domain.
- The same `<ref>` + `--base`.
- Instruction to produce output in the audit's existing format
  (no changes — reuse the skill as-is).

If a subagent errors or returns empty, log and continue. A single
audit failure doesn't kill the whole run.

Subagents that have no files to review emit a one-line
"<audit>: no domain-matching files" instead of running.

### Graceful degradation

`audit-all` respects what's installed. If `.octopus.yml` has
`skills: [audit-all, security-scan]` but not `money-review`, then:

- `depends_on` resolver logs the missing dep and skips it.
- Parallel phase dispatches only to installed audits.
- Report's summary line notes "2 of 4 audits ran; install
  money-review and tenant-scope-audit to enable the rest".

`--only=<list>` further narrows this: `--only=security` runs only
that one even if all four are installed.

### Consolidated report

Output shape (chat default; `--write-report` also persists to disk):

```
## 🎯 Summary
audit-all: 2 block, 5 warn, 3 info across 4 audits (security, money,
tenant, cross-stack). Files touched: 12. Cross-audit hotspots: 2.

## 🔥 Cross-audit hotspots

Files flagged by more than one audit — prioritize these first.

| File | Audits |
|---|---|
| api/src/.../BillingController.cs | security, money, tenant |
| api/src/.../WebhookHandler.cs | security, money |

## 🔒 security-scan
<security-scan's own output, unchanged>

## 💰 money-review
<money-review's own output, unchanged>

## 🏢 tenant-scope-audit
<tenant-scope-audit's own output, unchanged>

## 🔁 cross-stack-contract
<cross-stack-contract's own output, unchanged>
```

Every sub-report keeps its own summary footer
(`money-review: N block, N warn, N info (...)`) — that makes the
report copy-pasteable in pieces when reviewers want to comment on
specific audits in a PR thread.

### Bundle update

`bundles/quality-gates.yml` before:

```yaml
skills:
  - security-scan
  - money-review
  - tenant-scope-audit
roles:
  - backend-specialist
```

After:

```yaml
skills:
  - audit-all
roles:
  - backend-specialist
```

`expand_bundles()` + `_resolve_skill_dependencies()` ensure the four
audit skills still end up in the rendered `OCTOPUS_SKILLS` array.
Users who already declared individual audits in their `.octopus.yml`
keep them (union semantics); users who re-run `octopus setup`
against this bundle get everything.

### Errors

- `ref` unresolvable → the same fuzzy-match error the individual
  audits already emit.
- Missing `superpowers:dispatching-parallel-agents` skill → fall
  back to sequential execution with a warning. The result is the
  same, just slower.
- All four audit skills uninstalled → abort with
  "audit-all requires at least one installed audit skill".
- Empty diff → short-circuit, exit 0.

## Migration / Backward Compatibility

- `.octopus.yml` files that list the individual audit skills
  explicitly continue working unchanged.
- `quality-gates` bundle changes content; users who re-run
  `octopus setup` after updating get the new composition. Because
  `depends_on` resolves to the same set of skills, the final
  delivered `.claude/skills/` tree is equivalent.
- The `depends_on:` frontmatter is additive. Skills without it are
  untouched by the resolver.
- CHANGELOG will call out the bundle composition change.

## Implementation Plan

1. Extend `setup.sh`: add `_read_skill_depends_on()` (greps the
   skill's frontmatter for `depends_on:` lines) and
   `_resolve_skill_dependencies()` (fixed-point loop with cycle +
   depth guards). Call it from `expand_bundles()` after
   `_dedupe_array OCTOPUS_SKILLS`.
2. Create `skills/audit-all/SKILL.md` with frontmatter (name,
   description, `depends_on:` listing the four audits) + body
   sections (Invocation, Discovery, Parallel Execution, Report,
   Errors).
3. Create `skills/audit-all/templates/report-header.md.tmpl` — the
   consolidated summary + hotspots table skeleton.
4. Create `commands/audit-all.md` — thin dispatcher.
5. Rewrite `bundles/quality-gates.yml` to list only `audit-all` +
   roles.
6. Register `audit-all` in `cli/lib/setup-wizard.sh` (items, hints,
   legend), between `adr` and `backend-patterns` alphabetically.
7. Update `docs/features/skills.md` with an `audit-all` row
   (`quality-gates` bundle) and keep the individual audits' rows
   (they're still first-class).
8. Update `docs/features/bundles.md` — `quality-gates` row now
   reads `audit-all (pulls security-scan, money-review,
   tenant-scope-audit via depends_on) + backend-specialist role`.
9. Create `docs/features/audit-all.md` tutorial.
10. Update `README.md` Available-skills comment to insert
    `audit-all` alphabetically.
11. Mark RM-028 completed in `docs/roadmap.md` with a link to this
    spec and move it into the Completed / Rejected table.
12. Tests: `tests/test_audit_all.sh` (structural + `depends_on`
    frontmatter present + referenced audit skills exist) and an
    extension to `tests/test_bundles.sh` covering `depends_on`
    resolution (happy path + missing dep warning + cycle
    detection).

## Context for Agents

**Knowledge modules**: none new.
**Implementing roles**: `backend-specialist` (bash CLI + skill
markdown), `tech-writer` (tutorial + README).
**Related ADRs**: consider an ADR for the `depends_on:` mechanism —
it's a primitive that future composer skills will reuse and worth
recording the design choice.
**Skills needed**: `adr`, `feature-lifecycle`.
**Bundle**: `quality-gates` (existing) — `audit-all` becomes the
bundle's only skills entry; the existing audits are pulled in via
`depends_on`.

**Constraints**:
- Pure bash + python3 (already vendored). No new deps.
- Frontmatter parsing for `depends_on:` must be lightweight — no
  full YAML library; a `grep`/`awk` pass over the top of SKILL.md
  is enough because the contract allows only a simple array of
  strings. Reject or skip anything more complex.
- Parallel execution uses `superpowers:dispatching-parallel-agents`
  when available; sequential fallback is documented.
- Output format matches existing audit skills — reviewers should
  not need to learn a new format.
- `--only=` and `depends_on` resolver must not cross each other:
  `--only` filters what actually runs, `depends_on` only decides
  what ships in `.claude/skills/`.

## Testing Strategy

### Structural tests (`tests/test_audit_all.sh`)

1. `skills/audit-all/SKILL.md` exists with correct frontmatter
   (name, description, `depends_on:` containing the four audits).
2. `commands/audit-all.md` exists with correct `name: audit-all`.
3. `audit-all` registered in wizard items/hints/legend.
4. Every name in the `depends_on` list corresponds to an existing
   `skills/<name>/SKILL.md`.
5. SKILL.md documents Invocation, Discovery, Parallel Execution,
   Report, Errors sections.
6. README `# Available:` comment includes `audit-all`.
7. `bundles/quality-gates.yml` lists `audit-all`.

### `depends_on` resolution tests (extend `tests/test_bundles.sh`)

1. **Happy path**: bundle listing `audit-all` resolves to include
   the four dependency skills in `OCTOPUS_SKILLS`.
2. **Missing dep warning**: remove one audit from the cache
   fixture; expect resolver to warn but still ship `audit-all`
   itself.
3. **Cycle detection**: temporary fixture where skill A depends on
   B and B depends on A; expect abort with the "cycle detected"
   message.
4. **No `depends_on:`**: existing skills without the field remain
   unchanged after resolution.

### Integration (manual)

Run `/octopus:audit-all v1.7.0..v1.8.2` in the Octopus repo; expect
four sub-reports and the hotspots table.

## Risks

- **Parallel dispatch semantics in non-Claude agents** — Copilot,
  Codex, Gemini, OpenCode may not have a parallel-subagent
  mechanism. Mitigation: sequential fallback is documented and
  tested; the skill still works, just slower.
- **`depends_on` as a DSL creep** — today it's a plain array of
  skill names; future requests may push it toward conditional deps
  or version constraints. Mitigation: the spec fixes the contract
  ("array of strings, each a skill name") and documents the
  non-goals so the next PR has to re-spec before adding complexity.
- **Bundle diff confusion for existing users** — users who already
  installed `quality-gates` will see their `.octopus.yml` keep the
  old explicit list (additive) while the bundle YAML moved. They
  aren't broken, but their manifest now looks noisier than a fresh
  install. Mitigation: CHANGELOG entry explains; tutorial shows how
  to clean up to the new minimal form if desired.
- **`grep`-based frontmatter parsing failing on edge cases** —
  quoted dependency names, line-wrapped arrays. Mitigation: the
  contract restricts `depends_on` to a simple `- skill-name` list;
  the parser rejects anything outside that grammar with a clear
  error.

## Changelog

- **2026-04-19** — Initial draft.
