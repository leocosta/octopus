# Spec: Task Routing

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-20 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-034 |

## Problem Statement

Three Octopus workflow skills in the `starter` bundle —
`implement` (RM-030), `debugging` (RM-031), and
`receiving-code-review` (RM-032) — each ship with a reserved
`## Task Routing` section containing the same stub paragraph:

> When [...] consider whether domain-specific skills help —
> `dotnet` for .NET stack traces, the `frontend-specialist` role
> for UI-layer bugs, `tenant-scope-audit` for multi-tenant
> data-leak bugs, `money-review` for financial regressions.
>
> RM-034 will replace this paragraph with a decision matrix that
> auto-selects the right companion skill per task. Until
> RM-034 ships, the agent uses judgment and the installed-skills
> list.

The stub was reserved so RM-034 could edit in-place without
restructuring. This spec is RM-034 — it replaces that stub in
all three skills with a concrete decision matrix that tells the
agent which companion skills to consult based on observable
signals (file paths, keywords in task / error / comment
content, risk profile).

The matrix is the same across the three skills because the
signals that route to a companion skill are shared — a task
touching `api/**/*.cs` wants `dotnet` whether the trigger was
a feature request, a bug report, or a PR comment. The routing
table is factored into a single shared fragment that each of
the three skills references, avoiding three-way drift.

## Goals

- Replace the `## Task Routing` stub in all three starter
  skills (`implement`, `debugging`, `receiving-code-review`)
  with a concrete decision matrix.
- Factor the matrix into a single shared file so all three
  skills consult the same rules. One source of truth.
- Document the signals and companion skills explicitly so the
  agent has something to pattern-match against, not prose.
- Cover the common companion cases: stack/language
  (`dotnet` / `frontend-specialist` role), domain audits
  (`money-review` / `tenant-scope-audit` / `cross-stack-contract`),
  cross-workflow handoffs (between `implement` / `debugging` /
  `receiving-code-review`), and the pre-merge composer
  (`audit-all`).
- Degrade gracefully: when a companion skill isn't installed,
  the main workflow skill continues with `rules/common/*` and
  surfaces the install gap as a hint, not a block.
- Preserve the exact `## Task Routing` heading in each skill so
  the RM-034 edit is purely replacing section body, not moving
  the section itself.

## Non-Goals

- Adding routing to any skill other than the three starter
  workflow skills. Audit skills (`money-review`,
  `tenant-scope-audit`, …) are destinations of routing, not
  sources.
- New routing metadata in skill frontmatter. The shared fragment
  is plain markdown; no new schema.
- Programmatic signal evaluation (a script that parses the diff
  and picks skills automatically). The matrix is guidance the
  agent reads; it applies pattern-matching with judgment, not a
  mechanical rule engine.
- Changing any other section of the three skills. Only the
  `## Task Routing` body changes.
- A bundle or wizard change. RM-034 is a docs-only patch.
- Priority / tiebreaker semantics when multiple signals apply.
  Agents reading the matrix handle overlap using judgment —
  more than one companion skill can be consulted on the same
  task.

## Design

### Overview

Ship a single shared markdown fragment at
`skills/_shared/task-routing.md` that contains the decision
matrix. Each of the three starter workflow skills replaces
its `## Task Routing` section body with a short lead paragraph
plus an **include** reference to the shared fragment.

Because Octopus skills are plain markdown (no template engine
in the runtime), "include" here means the shared fragment is
**embedded verbatim** into each skill's SKILL.md at edit time
— this spec changes three SKILL.md files in one PR, copying
the same body into each. The `skills/_shared/task-routing.md`
file is the canonical source; the three SKILL.md files hold
copies. A lightweight test asserts that the three copies stay
byte-identical with the canonical fragment, catching drift on
future edits.

### Detailed Design

#### The shared fragment

`skills/_shared/task-routing.md`:

```markdown
<!-- Canonical task-routing matrix for the three starter workflow
     skills (implement, debugging, receiving-code-review).
     When you edit this file, the pre-commit / CI checks verify
     that each SKILL.md contains a byte-identical copy of the
     block between the BEGIN and END markers below. Edit once
     here; the sync is enforced by tests/test_task_routing.sh. -->

<!-- BEGIN task-routing -->
When a task starts, scan the signals below and consult the
matching companion skills alongside the core workflow. Signals
are heuristics — more than one may apply; treat them as a
checklist, not a switch statement.

**Stack / language signals**

| Signal | Consult |
|---|---|
| Paths under `api/**/*.cs`, `*.sln`, `*.csproj`; stack traces with `System.*` | `dotnet`, `backend-specialist` role |
| Paths under `app/**/*.tsx`, `*.jsx`, `*.vue`; UI-layer bugs; reviewer comments about rendering / accessibility | `frontend-specialist` role |
| Node/TypeScript backend (`apps/api/**/*.ts`, `package.json` with `express`/`fastify`/`hono`/`nestjs`) | `backend-patterns`, `backend-specialist` role |
| Astro / Next.js landing page (`lp/`, `apps/lp/`, `src/pages/`) | `frontend-specialist` role |

**Domain-audit signals**

| Signal | Consult |
|---|---|
| Keywords `payment`, `billing`, `split`, `fee`, `invoice`, `subscription`; paths `billing/`, `payment/` | `money-review` |
| New `DbSet<X>`, multi-tenant queries, `[Authorize]` changes, `IgnoreQueryFilters()` | `tenant-scope-audit` |
| Change touches both `api/` and `app/` (or `lp/`) in the same diff; DTO/endpoint changes | `cross-stack-contract` |
| Secrets, env vars, `detect-secrets` warnings, authentication paths | `security-scan` |
| Pre-merge on a non-trivial PR that touches billing or multi-tenant data | `audit-all` (composer — runs all four audits in parallel) |

**Cross-workflow signals**

| Signal | Consult |
|---|---|
| Trigger is a **new feature** or **refactor** (not a reported bug or review comment) | Stay in `implement` |
| Trigger is a **bug report**, **failing test**, **stack trace**, or **regression** | Hand off to `debugging` (Phase 3 uses `implement`'s TDD loop for the fix) |
| Trigger is a **PR review comment** | Hand off to `receiving-code-review` (Rule 1 verifies, then handoff back to `implement` or `debugging` per the comment's intent) |
| Task involves both docs and code | Compose with `feature-lifecycle` for docs (RFC / Spec / ADR), use the appropriate workflow skill for the code |

**Risk-profile signals**

| Signal | Consult |
|---|---|
| Large-scale / cross-module change (touches ≥ 3 modules) | Escalate `implement`'s plan-before-code gate to a spec via `/octopus:doc-spec`; add an ADR via `/octopus:doc-adr` if the change encodes a decision |
| Data migration, schema change, irreversible operation | Keep `debugging`'s Phase 3 regression test; consider an ADR; consider tagging the change for the destructive-action guard hook |
| Release-triggering change | Pair with `release-announce` (retention) or `feature-to-market` (acquisition) for the user-facing announcement after merge |

**Graceful degradation**

A companion skill that isn't installed in the current repo
doesn't block the workflow — the main skill continues with
`rules/common/*` and whatever else is available. Surface the
gap once, as a hint: "this task would benefit from
`<skill-name>`; add it to `.octopus.yml` to enable."

Don't stall. Don't block. Don't invent advice the missing skill
would have provided — point at the gap and move on.
<!-- END task-routing -->
```

#### Replacement in each SKILL.md

Each of the three skills currently has:

```markdown
## Task Routing

<the current stub paragraph naming RM-034>
```

This spec replaces that body with:

```markdown
## Task Routing

<!-- BEGIN task-routing -->
<content from skills/_shared/task-routing.md — byte-identical>
<!-- END task-routing -->
```

The lead sentence (first paragraph of the fragment) is the
same across all three skills because the signals are the same
regardless of whether the trigger was a feature, a bug, or a
review comment.

#### Drift-prevention test

`tests/test_task_routing.sh`:

1. Read the canonical fragment between `<!-- BEGIN
   task-routing -->` and `<!-- END task-routing -->` in
   `skills/_shared/task-routing.md`.
2. For each of the three skill files, extract the same block.
3. Assert byte-identical equality. Any drift fails the test.
4. Assert the block contains the four matrix headings
   (**Stack / language**, **Domain-audit**, **Cross-workflow**,
   **Risk-profile**) so a malformed fragment can't pass.
5. Assert the `## Task Routing` section in each skill no
   longer contains the `RM-034` placeholder string (the stub
   has been replaced).

### Migration / Backward Compatibility

- Additive docs change. The `## Task Routing` heading stays;
  only the body changes.
- Skills stay stack-neutral — the matrix mentions specific
  tools (`dotnet`, `backend-patterns`, …) only under the
  "consult if present" heading, so repos without those skills
  installed are not broken by the guidance.
- No `.octopus.yml` / bundle / wizard changes.
- CHANGELOG documents the RM-034 completion.
- `skills/_shared/` is a new path — the existing skill-delivery
  code (`deliver_skills`, symlinks) ignores it by default
  because it walks `skills/*/SKILL.md`, not `skills/_shared/*`.
  No risk of accidental delivery; the fragment is an authoring
  tool, not a shipped skill.

## Implementation Plan

1. `skills/_shared/task-routing.md` — create the canonical
   fragment with the four matrix sections + graceful-
   degradation paragraph + BEGIN/END markers.
2. `skills/implement/SKILL.md` — replace the `## Task Routing`
   body (stub paragraph) with the fragment body wrapped in
   BEGIN/END markers.
3. `skills/debugging/SKILL.md` — same replacement.
4. `skills/receiving-code-review/SKILL.md` — same replacement.
5. `tests/test_task_routing.sh` — drift-prevention test.
6. Update the existing RM-030/RM-031/RM-032 skill tests to
   ensure the Task Routing section no longer asserts the
   `RM-034` string (remove the `grep -q "RM-034"` assertions
   — the stub is gone).
7. `docs/roadmap.md` — move RM-034 from Backlog Cluster 4 into
   Completed with a link to this spec.

## Context for Agents

**Knowledge modules**: none new.
**Implementing roles**: `backend-specialist` (bash +
markdown), `tech-writer` (docs update).
**Related ADRs**: an ADR documenting the "shared fragment in
`skills/_shared/`" pattern would be useful if future skills
adopt it. Defer to a follow-up RM.
**Skills needed**: `adr`, `feature-lifecycle`.
**Bundle**: none (docs change to existing starter skills).

**Constraints**:
- Pure markdown; no new schema.
- Three copies of the fragment must be byte-identical with the
  canonical source; a test enforces this.
- The `## Task Routing` heading text stays unchanged in all
  three skills.
- The BEGIN/END markers are HTML comments so they render
  invisibly in previews but grep-friendly for the sync test.
- Don't touch any other section of the three skills.
- `skills/_shared/` must not be delivered as a skill — verify
  no test regresses around skill discovery.

## Testing Strategy

### `tests/test_task_routing.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL="$SCRIPT_DIR/skills/_shared/task-routing.md"

echo "Test 1: canonical fragment exists"
[[ -f "$CANONICAL" ]] || { echo "FAIL: $CANONICAL not found"; exit 1; }
echo "PASS: canonical present"

echo "Test 2: canonical contains the four matrix headings"
for heading in "Stack / language signals" "Domain-audit signals" "Cross-workflow signals" "Risk-profile signals"; do
  grep -qF "$heading" "$CANONICAL" \
    || { echo "FAIL: canonical missing '$heading'"; exit 1; }
done
echo "PASS: canonical structure valid"

echo "Test 3: each starter workflow skill embeds the canonical block"
extract_block() {
  awk '/<!-- BEGIN task-routing -->/{flag=1; next} /<!-- END task-routing -->/{flag=0} flag' "$1"
}
canonical_body="$(extract_block "$CANONICAL")"
for f in \
  "$SCRIPT_DIR/skills/implement/SKILL.md" \
  "$SCRIPT_DIR/skills/debugging/SKILL.md" \
  "$SCRIPT_DIR/skills/receiving-code-review/SKILL.md"
do
  skill_body="$(extract_block "$f")"
  if [[ "$skill_body" != "$canonical_body" ]]; then
    echo "FAIL: $f task-routing body drifted from canonical"
    diff <(printf '%s\n' "$canonical_body") <(printf '%s\n' "$skill_body") | head -20
    exit 1
  fi
done
echo "PASS: three skills synced with canonical"

echo "Test 4: the RM-034 placeholder string is gone from all three skills"
for f in \
  "$SCRIPT_DIR/skills/implement/SKILL.md" \
  "$SCRIPT_DIR/skills/debugging/SKILL.md" \
  "$SCRIPT_DIR/skills/receiving-code-review/SKILL.md"
do
  if grep -q "RM-034 will replace this paragraph" "$f"; then
    echo "FAIL: $f still contains the v1 RM-034 stub"
    exit 1
  fi
done
echo "PASS: stub replaced in all three skills"
```

### Existing-test updates

The existing `tests/test_implement.sh`,
`tests/test_debugging.sh`, and
`tests/test_receiving_code_review.sh` each assert:

```bash
grep -q "RM-034" "$SKILL_FILE" \
  || { echo "FAIL: Task Routing stub does not mention RM-034"; exit 1; }
```

RM-034's completion invalidates that assertion. Each of the
three test files gets the grep removed — replaced by an
assertion that the skill includes the BEGIN/END markers
referencing the shared fragment:

```bash
grep -q "<!-- BEGIN task-routing -->" "$SKILL_FILE" \
  || { echo "FAIL: Task Routing section missing the shared-fragment markers"; exit 1; }
```

### Manual / integration

- Preview the three SKILL.md files in a markdown renderer and
  verify the matrix renders cleanly.
- Run `octopus setup` in a fresh repo; confirm
  `.claude/skills/implement/SKILL.md` (etc.) is symlinked
  correctly and the full matrix is readable.

## Risks

- **Drift between the canonical fragment and the three
  copies.** Mitigation: the test enforces byte equality on
  every CI run. If someone edits one SKILL.md but not the
  shared fragment, CI fails with a diff output so the drift
  is obvious.
- **Matrix becoming stale as new skills ship.** Each new
  workflow skill (or new domain audit) that should be
  routable to needs a row in the matrix. Mitigation: add a
  checklist item to `skills/writing-skills/SKILL.md` (and the
  spec template) reminding the author to update the matrix if
  the new skill is a routing target.
- **Overlapping signals confusing the agent.** The matrix
  notes that multiple signals may apply and treats the rule
  set as a checklist, not a switch. Mitigation: the Non-Goals
  section declares tiebreaker semantics out of scope; the
  graceful-degradation paragraph keeps overlap non-fatal.
- **False sense of completeness.** The matrix lists common
  signals; an agent might treat "not in the matrix" as "no
  companion skill applies." Mitigation: the lead sentence
  frames the matrix as "scan the signals" (heuristic) rather
  than "this is exhaustive"; graceful degradation applies to
  unmapped signals too.
- **Canonical fragment getting delivered as a skill.** The
  path `skills/_shared/` sits next to real skill dirs; the
  delivery code must not symlink it. Mitigation: the test
  verifies no skill-discovery regression, and the directory
  name starts with `_` to signal "not a real skill" by
  convention. Confirm the delivery code walks
  `skills/*/SKILL.md` (not `skills/_*/SKILL.md`) during
  implementation.

## Changelog

- **2026-04-20** — Initial draft.
