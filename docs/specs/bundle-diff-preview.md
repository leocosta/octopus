# Spec: Bundle Diff Preview

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-21 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-027 |

## Problem Statement

In the Full-mode wizard (`cli/lib/setup-wizard.sh`), users pick
bundles / skills / roles one at a time without any signal of how
much each choice costs — in lines added to the generated config or
in approximate tokens loaded per AI session. The current UX is
"check the box, hope for the best"; users who care about context
budget can only learn the cost after running setup and inspecting
the output.

## Goals

- Show impact per candidate item before confirming a selection:
  - Lines added to the generated CLAUDE.md / agent output file.
  - Approximate token count (using a simple words × 1.3 heuristic).
  - Which rules / roles / MCP servers the item pulls in
    transitively (e.g. a bundle that includes a skill that
    requires a rule file).
- Make cumulative impact visible as selections accumulate — a
  running total at the bottom of the picker.
- Keep the existing flow fast: computing impact must not add
  perceptible latency (target ≤ 200 ms per item on a dev laptop).

## Non-Goals

- Exact token counts per provider. A generic heuristic is enough.
- Impact preview in Quick mode — it already auto-picks bundles
  from persona questions; the user is not choosing per-item there.
- Network calls to any tokenizer. Purely local computation.

## Design

### Overview

In Full-mode wizard pickers (bundles, skills, roles, MCP, rules),
each candidate line carries an inline impact annotation showing
approximate cost: **lines added** to the generated agent output
file and **tokens** (words × 1.3 heuristic). Transitive
dependencies pulled in by a bundle or skill are listed inline
after the cost.

A running total — **selected so far: +N lines, ~M tokens** —
updates at the bottom of the picker as items are toggled.

Impact is computed offline: no tokenizer, no network. The
computation is amortised per session — each candidate's cost is
measured once (the first time the picker opens) and cached in a
bash associative array for the lifetime of the wizard run.

The annotation is rendered by whatever renderer is active
(`fzf`, `whiptail`, `dialog`, or the bash fallback). Renderers
that cannot show inline annotations (e.g. `whiptail` item
descriptions are narrow) gracefully degrade: running total still
prints between questions; per-item cost moves to a brief preview
line after selection.

### Detailed Design

**New file: `cli/lib/wizard-impact.sh`**

Sourced by `cli/lib/setup-wizard.sh` once, near the top. Exports:

- `_wi_measure <kind> <name>` — computes impact for a single
  item. Writes three space-separated fields to stdout:
  `<lines> <tokens> <deps-csv>` where `<deps-csv>` is `-` when
  there are none.
- `_wi_annotate <kind> <name>` — wraps `_wi_measure` into a
  human-readable suffix: `(+N lines, ~M tokens)` or
  `(+N lines, ~M tokens) — pulls: a, b, c` when deps exist.
- `_wi_total_reset` / `_wi_total_add <kind> <name>` /
  `_wi_total_print` — running-total tracker, cleared when each
  sub-picker starts, accumulated as the user toggles items.

Internal: `WI_IMPACT_CACHE` associative array keyed by
`<kind>:<name>`. First call for a key measures; subsequent calls
hit the cache.

**Source of truth per kind:**

| Kind   | File(s) counted                       | Deps surfaced              |
|--------|---------------------------------------|----------------------------|
| rule   | `rules/<name>.md`                     | none                       |
| skill  | `skills/<name>/SKILL.md`              | none (templates/ excluded) |
| role   | `roles/<name>.md`                     | none                       |
| bundle | yaml + each included skill/rule/role  | skills list from `skills:` |
| mcp    | `mcp/<name>.json`                     | none                       |

Token heuristic: `tokens = ceil(words × 1.3)`. `words` counted
via `wc -w` on the file(s). Deliberately coarse — goal is
order-of-magnitude guidance, not accounting.

**Modified file: `cli/lib/setup-wizard.sh`**

Each `_wizard_sub_*` function (bundles, skills, roles, mcp,
rules) gets a pre-pass:

```bash
_wi_total_reset
local annotated=()
for item in "${items[@]}"; do
  annotated+=("$item $(_wi_annotate <kind> "$item")")
done
```

The annotated array is what goes to `_multiselect`. After
`_multiselect` returns, iterate `WIZARD_SELECTED` and call
`_wi_total_add` for each, then `_wi_total_print` once.

**Renderer adaptation (`_multiselect_*` in setup-wizard.sh):**

- `_multiselect_bash` — prints the annotated string directly;
  no change needed beyond taking the extended item list.
- `_multiselect_fzf` — splits on first space for the toggle
  token, keeps the rest as visible label. fzf's preview pane
  (already wired for hints) also shows the deps line.
- `_multiselect_whiptail` / `_multiselect_dialog` — these use
  narrow description columns. Fallback: strip the deps suffix,
  keep only `(+N lines, ~M tokens)`.

### Migration / Backward Compatibility

<!-- How do existing users/systems transition? What breaks? -->

## Implementation Plan

1. **Create `cli/lib/wizard-impact.sh`.** Implements
   `_wi_measure`, `_wi_annotate`, `_wi_total_reset /_add /
   _print` with the `WI_IMPACT_CACHE` associative array.
   Handles all five kinds (rule, skill, role, bundle, mcp)
   using `wc -w` + the 1.3 multiplier. Reads bundle YAML with
   the existing `parse_octopus_yml`-style helper already
   sourced by `setup.sh`.
2. **Create `tests/test_wizard_impact.sh`.** Covers: per-kind
   measurement against real fixtures in the repo tree,
   annotation string format, running-total accumulation, cache
   hit on repeated calls. Depends on Step 1.
3. **Source `wizard-impact.sh` from `cli/lib/setup-wizard.sh`.**
   One line near the top of the file, alongside existing
   sources. Depends on Step 1.
4. **Wire the pre-pass + post-pass into each `_wizard_sub_*`
   function** (`_wizard_sub_bundles`, `_wizard_sub_skills`,
   `_wizard_sub_roles`, `_wizard_sub_mcp`,
   `_wizard_sub_rules`). Build `annotated=()`, pass to
   `_multiselect`; after return, call `_wi_total_add` +
   `_wi_total_print` + the post-picker deps recap. Depends
   on Step 3.
5. **Adapt `_multiselect_bash`, `_multiselect_fzf`,
   `_multiselect_whiptail`, `_multiselect_dialog`.** Each
   renderer receives the annotated item string; fzf gets a
   preview-line carrying the deps; whiptail/dialog strip the
   deps suffix. Depends on Step 4.
6. **Print the "~ approximation" banner once per wizard run.**
   A flag in `wizard-impact.sh` (`WI_BANNER_SHOWN`) keeps it
   to the first picker. Depends on Step 4.
7. **Move RM-027 from Backlog to Completed** in
   `docs/roadmap.md` and flip the spec's `Status` to
   `Implemented (<date>)`.

## Context for Agents

**Knowledge modules**: N/A (no domain knowledge required; pure
wizard UX).
**Implementing roles**: backend-specialist (bash).
**Related ADRs**: none.
**Skills needed**: `adr`, `feature-lifecycle`.
**Bundle**: N/A — wizard CLI enhancement, not a new skill.

**Constraints**:
- Pure bash, no external dependencies.
- Offline measurement; no network, no tokenizer library.
- Must not exceed ~200 ms added latency per sub-picker on a
  dev-class laptop.
- Must work in every renderer (`fzf`, `whiptail`, `dialog`,
  bash fallback); graceful degradation for narrow columns.
- Source tree layout is the source of truth for measurement
  (no pre-computed cache file).

## Testing Strategy

- **Unit tests** in `tests/test_wizard_impact.sh`:
  - `_wi_measure` against real fixtures for each kind (rule,
    skill, role, bundle, mcp) — assert non-zero `lines` and
    `tokens`, and correct deps CSV for bundles.
  - `_wi_annotate` output string contains `+`, `lines`, `~`,
    `tokens`; deps suffix appears only when there are deps.
  - Running-total accumulation: `_wi_total_reset` clears;
    consecutive `_wi_total_add` calls sum across kinds;
    `_wi_total_print` renders the expected format.
  - Cache hit: second `_wi_measure` call on the same key does
    not re-read from disk (verified by stubbing `wc`).
- **Manual visual check** before merge: run `octopus setup` in
  Full mode against a test repo and confirm the annotations
  render in all five pickers, the running total updates as
  items toggle, and the one-line "~ approximation" banner
  prints exactly once per wizard run.
- **No e2e harness.** The wizard is an interactive TUI; no
  low-cost harness exists. Manual check covers the visual gap
  unit tests cannot.

## Risks

- **Accumulated measurement latency.** Measuring 19 skills +
  7 bundles + 5 roles + N MCP fragments at the start of the
  wizard could exceed the 200 ms budget on slow disks.
  Mitigation: measure on-demand per sub-picker, not eagerly at
  wizard start; rely on the per-key cache to keep repeated
  pickers fast.
- **Heuristic divergence.** `words × 1.3` is approximate; real
  tokenisation varies by model. Users may make scope decisions
  trusting the number as exact. Mitigation: render a one-line
  "~ approximation; real cost varies by model" banner at the
  first picker each wizard run.
- **Stale cache within a session.** If the user edits a
  `SKILL.md` during the wizard run (unlikely), the cached
  impact serves an outdated value. Mitigation: accept — the
  wizard is expected to run atomically against a stable tree.
- **Narrow renderers hide deps.** `whiptail` and `dialog` have
  narrow description columns; the `— pulls: a, b, c`
  dependency list is truncated or omitted. Mitigation: after
  each picker closes, print a one-line recap listing the deps
  each selected item pulled in, independent of the renderer.

## Changelog

- **2026-04-21** — Initial draft
- **2026-04-21** — Design session completed (dog-food of `/octopus:doc-design`)
