# Spec: Bundles Setup

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-19 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **RFC** | N/A |
| **Roadmap** | RM-039 |

## Problem Statement

The current `octopus setup` wizard presents 13 skills, 5 roles, 4 MCP
servers, 3 rules, 5 agents, and ~6 advanced toggles as independent
checkboxes. A new user has to understand each item to decide whether
it applies — high cognitive load, low adoption, common "paradox of
choice" abandonment on first run. Users frequently under-select
(missing valuable skills they didn't know to look for) or over-select
(picking everything to be safe, polluting their repo with unused
artifacts).

Octopus ships useful skills (`money-review`, `tenant-scope-audit`,
`cross-stack-contract`, `feature-to-market`, etc.) that cluster
naturally around intent ("we're a SaaS", "we produce content",
"we document with RFCs") but the wizard does not expose the cluster —
it exposes the atoms.

The skill catalog will keep growing. Without a packaging layer, each
new skill makes the wizard worse.

## Goals

- Introduce **bundles** as the primary setup path: curated, named
  groups of skills + roles + rules + MCP servers + hooks that express
  an intent (e.g., `saas-b2b`, `growth`, `dotnet-api`) instead of
  requiring users to select components individually.
- Add a **persona mini-wizard** that maps 4–6 yes/no questions to the
  right set of bundles — so users never need to know the catalog to
  get a sensible configuration.
- Keep individual component selection available as **advanced mode**
  for power users.
- Make bundle files declarative YAML so the community can add new
  bundles without changing CLI code.
- Establish the convention that **every future skill must belong to a
  bundle** (or ship with a new bundle); loose skills never land.

## Non-Goals

- Repo autodetection (scanning `package.json` / `*.csproj` to suggest
  stacks). Deferred to v2 — valuable but easy to get wrong.
- Bundle versioning / migration. v1 treats bundles as static YAML
  re-read on every `octopus setup`; updating the Octopus release pulls
  new bundle definitions automatically.
- A GUI picker. v1 remains TUI (fzf/whiptail/bash prompt fallback).
- Importing bundles from external registries. v1 ships bundles bundled
  with the Octopus install.
- Replacing `.octopus.yml` top-level fields. The manifest continues to
  accept explicit `skills:`, `roles:`, etc. — bundles are additive.

## Design

### Overview

A **bundle** is a YAML file at `bundles/<name>.yml` in the Octopus
install root. It declares which skills, roles, rules, mcp servers, and
hooks its repos should get, plus a short description shown in the
wizard. `.octopus.yml` gains a new top-level key `bundles:` (list of
names). During setup, the loaded bundles are **expanded** into the
component lists at manifest-parse time, then merged with explicit
`skills:` / `roles:` / etc. that the user may still declare.

The wizard gains a **Quick path**:

1. Greeting + 4–6 persona questions.
2. Answer set maps to a proposed bundle list.
3. User confirms (or tweaks), and that becomes `bundles:` in
   `.octopus.yml`. No other multiselects required.

The existing **Full path** (all individual multiselects) remains,
opt-in via `octopus setup --mode=full`.

### Detailed Design

#### Bundle file format

`bundles/<name>.yml`:

```yaml
# Human-readable metadata
name: saas-b2b
description: Multi-tenant SaaS for external customers — quality gates for billing, tenant scope, and API/frontend contract.
category: intent            # foundation | intent | stack
persona_question: |
  Is this a SaaS product for external customers (billing, multi-tenant)?
persona_default: false      # default answer when the user skips

# Component lists — same keys as .octopus.yml
skills:
  - money-review
  - tenant-scope-audit
  - security-scan
roles:
  - backend-specialist
  - product-manager
mcp: []
rules: []
hooks: null                 # null = don't touch; true/false overrides
```

Fields:
- `name` (required) — must match the filename.
- `description` (required) — one-sentence summary for the wizard.
- `category` (required) — `foundation`, `intent`, or `stack`. Drives
  ordering and default behavior (foundation is always suggested;
  intent and stack come from persona answers).
- `persona_question` (optional) — yes/no question shown in the
  persona mini-wizard. If absent, the bundle is hidden from the
  persona path but still selectable in Quick/Full.
- `persona_default` (optional, default `false`) — default answer.
- `skills`, `roles`, `mcp`, `rules`, `hooks` — same shape as
  `.octopus.yml`. Empty or omitted means "add nothing from this key".

#### Manifest changes

`.octopus.yml` gains:

```yaml
bundles:
  - starter
  - quality-gates
  - cross-stack
  - dotnet-api
```

Parse-time expansion rules:

1. Read `bundles:` first. For each bundle name, load
   `bundles/<name>.yml` from the Octopus install root. Abort with
   "unknown bundle '<name>'" if missing.
2. Union the skills, roles, rules, mcp across all bundles
   (de-duplicated).
3. Merge with the user's explicit top-level lists — the user's
   entries **add**, never remove. (Explicit removal requires
   `octopus setup --mode=full` to deselect and re-save.)
4. Apply `hooks` precedence: explicit `hooks:` in `.octopus.yml`
   wins; otherwise first non-null bundle value wins.

Resulting manifest — logically — is identical to one written by hand
with the expanded lists, so all downstream delivery code
(`deliver_skills`, `deliver_roles`, `deliver_mcp`, etc.) stays
untouched. Bundles are a *preprocessing* layer.

#### Wizard flow

Pre-flight prompt: `Setup mode — [1] Quick (recommended) [2] Full
[3] Reconfigure (keep current)`.

**Quick mode** (new default):

1. **Foundation** — `starter` is auto-included; brief one-liner shown.
2. **Persona questions** — read every bundle with a
   `persona_question`, show them in order
   (`foundation` → `intent` → `stack`). Y/N each, using the existing
   `_ask_yn` helper.
3. **Preview** — show the computed bundle list and the final
   skills/roles/rules/mcp that will be written, with an edit option.
4. **Write** `.octopus.yml` with `bundles:` only (no expanded
   `skills:` list — expansion happens at delivery time).

**Full mode** (`--mode=full`):

1. Ask for bundles first (multiselect across the bundle catalog).
2. Then allow individual additions to each component list.
3. Write `.octopus.yml` with both `bundles:` and any extra explicit
   entries.

#### Bundles shipped in v1

| Bundle | Category | Persona question | Contents |
|---|---|---|---|
| `starter` | foundation | (none — auto-include) | skills: `adr`, `feature-lifecycle`, `context-budget` |
| `quality-gates` | intent | "Is this a SaaS product for external customers (billing, multi-tenant)?" | skills: `security-scan`, `money-review`, `tenant-scope-audit`; roles: `backend-specialist` |
| `growth` | intent | "Does your team produce marketing content alongside code?" | skills: `feature-to-market`; roles: `social-media` |
| `docs-discipline` | intent | "Do you document with RFCs, specs, and ADRs?" | skills: `plan-backlog-hygiene`, `continuous-learning`; roles: `tech-writer` |
| `cross-stack` | intent | "Does your repo contain both an API and a separate frontend?" | skills: `cross-stack-contract`; roles: `backend-specialist`, `frontend-specialist` |
| `dotnet-api` | stack | "Primary backend language is .NET?" | skills: `dotnet`, `backend-patterns`, `e2e-testing` |
| `node-api` | stack | "Primary backend language is Node/TypeScript?" | skills: `backend-patterns`, `e2e-testing` |

Only one of the `stack` bundles can be picked per repo (the persona
flow asks "primary backend?" as a single-select).

#### New-skill convention

Every future skill spec must include, in its **Metadata** or
**Context for Agents** section, a declaration such as:

```
Bundle: quality-gates (existing) — add to skills list.
```

or, when none fits:

```
Bundle: <new-bundle-name> (proposed) — new bundle file ships with this
skill; see section "Bundle Design" below.
```

A skill cannot merge without a bundle decision. This is enforced
socially (PR checklist) in v1, not mechanically.

### Migration / Backward Compatibility

- Existing repos with `.octopus.yml` that do NOT have `bundles:`
  continue to work. All current fields keep their current meaning.
- Existing wizard flows remain available via `octopus setup --mode=full`
  (alias: `--full`). The new quick mode is opt-in via the pre-flight
  prompt; existing users re-running `setup` are asked whether to
  switch.
- An `octopus setup --migrate-to-bundles` subcommand (v1.7+) can
  suggest bundles that match an existing explicit configuration,
  rewriting `.octopus.yml` in-place. Out of scope for v1.

## Implementation Plan

1. `bundles/starter.yml`, `quality-gates.yml`, `growth.yml`,
   `docs-discipline.yml`, `cross-stack.yml`, `dotnet-api.yml`,
   `node-api.yml` — seven YAML files with the schema above.
2. `setup.sh` — new function `expand_bundles()` that reads the
   manifest's `bundles:` list, loads each YAML, and unions their
   component lists into the existing `OCTOPUS_SKILLS` / `_ROLES` /
   `_RULES` / `_MCP` arrays before delivery.
3. `cli/lib/setup-wizard.sh` — new `_wizard_sub_bundles()` function
   rendering the persona questions; pre-flight mode prompt updated to
   offer Quick / Full / Reconfigure.
4. `cli/lib/setup-wizard.sh` — Quick-mode path writes `.octopus.yml`
   with only `bundles:` (no expanded `skills:` list).
5. `tests/test_bundles.sh` — new tests covering: bundle file parsing,
   expansion into component lists, manifest round-trip, wizard flow
   for each persona answer combination.
6. `docs/features/bundles.md` — tutorial (Enable → Use → Customize →
   Author a new bundle → Persona questions → Migration from
   explicit).
7. `docs/features/skills.md` — add a "Bundle membership" column to
   the skills table.
8. `README.md` — update the `.octopus.yml` snippet to show
   `bundles:` as the preferred form.
9. `templates/spec.md` — update the "Context for Agents" section to
   require a **Bundle** declaration for new skills (per the
   new-skill convention).

## Context for Agents

**Knowledge modules**: none new.
**Implementing roles**: `backend-specialist` (CLI is bash), `tech-writer` (tutorial + README).
**Related ADRs**: none yet — consider an ADR for the bundle/manifest expansion precedence model.
**Skills needed**: `adr`, `feature-lifecycle`.

**Constraints**:
- Pure bash, no external dependencies beyond what Octopus already uses (`python3` for YAML parsing, already vendored).
- Fully backward compatible with existing `.octopus.yml` files.
- Bundles are additive to explicit lists; never remove user selections.
- TUI only (fzf / whiptail / bash fallback) — no GUI.
- The `bundles:` expansion must run BEFORE any delivery function
  (`deliver_skills`, `deliver_roles`, …) so downstream code is
  oblivious to bundles.

## Testing Strategy

- **Unit (bash)**:
  - Parse a bundle YAML file and verify name / description /
    component lists.
  - `expand_bundles` unions components across 2+ bundles, handles
    duplicates, respects hooks precedence.
  - Malformed bundle file → clear error, no silent swallow.
  - Unknown bundle name in `.octopus.yml` → abort with suggestion.
- **Integration**:
  - Run the full Quick-mode wizard answering each persona question
    in every combination (16+ combinations across binary answers) —
    assert the resulting `.octopus.yml` matches the expected bundle
    list.
  - Re-run `octopus setup` on a manifest containing `bundles:` only
    and verify the delivered `.claude/CLAUDE.md`, `.claude/skills/`,
    etc., match the expanded view.
- **Docs**:
  - `docs/features/bundles.md` has code examples for each supported
    scenario (Enable, Customize, Author, Migrate).

## Risks

- **Curation drift** — bundles become stale if new skills aren't
  added to an appropriate bundle. Mitigated by the new-skill
  convention (social enforcement via PR checklist, spec template).
- **Over-bundling** — users feel bundles force them into choices
  they don't want. Mitigated by keeping Full mode and allowing
  explicit lists alongside `bundles:`.
- **Persona question wording** — if questions are ambiguous, users
  pick wrong bundles. Mitigated by shipping tutorial with examples
  and iterating on wording based on feedback.
- **YAML expansion correctness** — precedence bugs between bundle
  and explicit entries could silently drop skills. Mitigated by
  integration tests that assert round-trip equivalence between a
  bundle-only manifest and its hand-expanded twin.
- **Versioning** — a bundle's contents change in a later Octopus
  release. Users re-run `setup` and get the new contents silently.
  Mitigated by showing a diff in the wizard when bundle contents
  changed since the last run. Out of scope for v1 UI; documented
  as a known limitation.

## Changelog

- **2026-04-19** — Initial draft.
