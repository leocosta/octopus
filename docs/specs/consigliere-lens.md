# Spec: Consigliere Lens Profile

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo |
| **Status** | Draft |
| **RFC** | N/A |

## Problem Statement

RM-110 closes Cluster 19. The three engines (`hygiene` RM-107, `synthesize` RM-108, `briefing` RM-109) are generic and read like generic reports on any knowledge root. The consigliere workspace (RM-099…104) is one such root — already declared in `cli/lib/knowledge-roots.default` with `lens_profile: consigliere` reserved (RM-106). But when an engine runs against the workspace, its output should read like the **consigliere** (RM-101): political-risk surfaced, the per-node `playbook.md` heuristics applied, the "thinks like you" voice — not a flat list. That is the lens this item attaches.

Where Cluster 19's engines multiply *any* base, the lens makes them multiply the **manager** specifically — delivering the original Cluster 17 intent (proactive / cross-node / maintenance for the manager) by reusing the engines rather than duplicating them. Read-only; honors the ADR-007 write-guard (the consigliere root already carries `write_policy: adr-007`).

See [research](../research/2026-05-31-knowledge-root-operations.md) and the consigliere cluster (RM-099…104).

## Goals

- Make the engines apply the **consigliere lens** when a root declares `lens_profile: consigliere`: surface political-risk, fold the relevant per-node `playbook.md` heuristics, and narrate in the consigliere's voice (the RM-101 role).
- A deterministic layer that surfaces the lens inputs (the root's `lens_profile`, a node's `playbook.md`, the political-risk field of its `state.md`) so the SKILL.md has grounded material to frame.
- Reuse the engines unchanged — the lens is a wrapper/profile, not a fork of `hygiene`/`synthesize`/`briefing`.
- Honor ADR-007: lens output is read-only over the workspace; any engine `--fix` against the consigliere root obeys `write_policy: adr-007`.

## Non-Goals

- New hygiene/synthesis/briefing logic — RM-107/108/109; the lens frames their output.
- Changing the registry schema — `lens_profile` already exists (RM-106).
- The consigliere capture/consult/playbook skills — RM-100/102/103; the lens consumes their artifacts, it does not replace them.
- A lens for any other profile — only `consigliere` exists; a generic lens framework is YAGNI until a second profile appears.

## Design

### Overview

A `consigliere-lens` skill wraps an engine run against the consigliere root; a deterministic helper `cli/lib/consigliere-lens.sh` (`octopus lens`) surfaces per-node lens-context (playbook + political-risk); the **opus** consigliere role (RM-101) frames the engine output through it. The three engines (`hygiene`/`synthesize`/`briefing`) stay generic and untouched — the lens is a wrapper + profile, not a fork.

### Detailed Design

**Flow.**

1. Run the chosen engine read-only against the workspace: `octopus hygiene|synthesize|briefing --root consigliere` → generic findings (`section|root|node|detail`).
2. For each finding's node, `octopus lens context <node>` surfaces the grounded lens material.
3. The consigliere role (opus) reframes the findings *with* that material — political-risk surfaced, the node's `playbook.md` heuristics applied (push/pull), the "thinks like you" voice — grounded, each line citing `(src: <node>)` and the playbook/state line it drew from.

**`octopus lens` helper** (`cli/lib/lens.sh` → `cli/lib/consigliere-lens.sh`):

- `octopus lens profile <root>` → the root's `lens_profile` (via `kr meta`); empty = no lens, the skill exits cleanly.
- `octopus lens context <node>` → the node's lens material, deterministic and grounded:
  - `playbook|<sibling playbook.md path>` — the node's `state/journal/playbook` trio sibling (RM-099),
  - `risk|<bullet>` — each line under the node's `## Political risk` section,
  - `blocker|<bullet>` — each `## Blockers` line (owner / since).

**Model tier.** The lens voice is the RM-101 `consigliere` role (`model: opus`) — **not** the engines' cheap-tier narration. Political nuance warrants the stronger model; the skill invokes it via `octopus ask --role consigliere` (or the assistant's equivalent).

**Write-guard (ADR-007).** The lens is read-only: it composes engine runs **without** `--fix` and never writes the workspace. The consigliere root already carries `write_policy: adr-007`; the skill asserts no-write.

**Placement.** The `consigliere-lens` skill registers in the **`consigliere`** bundle (manager-specific, ADR-008); the engines it wraps stay in `quality`.

**Invocation** `/octopus:consigliere-lens [--engine hygiene|synthesize|briefing] [--daily|--weekly]` (default `--engine briefing --daily`).

### Migration / Backward Compatibility

Additive — a new `octopus lens` helper and `consigliere-lens` skill. The consigliere root and its `lens_profile` already exist (RM-106); the three engines are unchanged. No existing surface changes.

## Implementation Plan

1. **Lens-context helper** — `cli/lib/consigliere-lens.sh` + `cli/lib/lens.sh` (`octopus lens`), usage line in `cli/octopus.sh`: `profile <root>` (via `kr meta`) and `context <node>` (sibling `playbook.md` + the node's `## Political risk` / `## Blockers` lines).
2. **`consigliere-lens` skill** — runs an engine against the consigliere root, calls `octopus lens context` per finding, frames via the RM-101 `consigliere` role (opus), grounded; read-only (no `--fix`).
3. **Command + bundle** — `commands/consigliere-lens.md`; register the skill in `bundles/consigliere.yml`.
4. **Tests** — helper `context`/`profile` extraction over a fixture workspace; SKILL.md structural (frontmatter, invocation, consigliere role/opus, grounding `(src:`, no-write).

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [backend-developer, architect, consigliere]
**Related ADRs**: [ADR-007 (write-guard), ADR-008 (consigliere bundle separation), ADR-009 (config scoping)]
**Skills needed**: [adr, doc-design, knowledge-hygiene, knowledge-synthesize, knowledge-briefing, playbook-review]
**Bundle**: the lens belongs to the `consigliere` bundle (it is manager-specific, ADR-008), even though the engines it wraps live in `quality`. Settle the exact placement in design.

**Constraints**:
- Pure bash for the deterministic lens-context surfacer; the voice is the LLM (RM-101 role).
- Reuse the engines as-is — no fork of hygiene/synthesize/briefing.
- Read-only over the workspace; honor `write_policy: adr-007`.
- The deterministic layer stays language-neutral (per RM-108); the lens framing is the model's.

## Testing Strategy

- Helper fixtures over a synthetic workspace (`contexts/payments/{state.md, playbook.md}`): `octopus lens context state.md` emits the sibling `playbook|` path, a `risk|` line from `## Political risk`, and a `blocker|` line from `## Blockers`. `octopus lens profile consigliere` returns `consigliere`; an unprofiled root returns empty.
- Read-only: assert the lens path runs no engine `--fix` and writes nothing into the workspace.
- Structural assertions on `skills/consigliere-lens/SKILL.md` (frontmatter, invocation, names the `consigliere` role, opus, `(src:` grounding, ADR-007 no-write), mirroring `test_knowledge_hygiene.sh`; bundle registration in `bundles/consigliere.yml`.

## Risks

- **Lens scope creep.** A "thinks like you" voice can drift into inventing political read not grounded in `state.md`/`playbook.md`. Mitigation: the lens cites the playbook/state lines it draws from, like the briefing's grounding.
- **Wrapper vs per-engine branching.** Editing three SKILL.md wrappers couples them to the consigliere; a single wrapper skill keeps the engines generic. The design must pick the decoupled option.

## Changelog

- **2026-05-31** — Initial draft (stub pre-filled from Cluster 19 research + the consigliere cluster).
- **2026-05-31** — Design session completed. Settled: wrapper skill (engines stay generic, not forked); consigliere-scoped deterministic lens-context helper (`octopus lens`); opus consigliere role for the voice (not cheap-tier); read-only (no `--fix`, ADR-007); `consigliere` bundle placement. Detailed Design, Implementation Plan, Testing filled.
