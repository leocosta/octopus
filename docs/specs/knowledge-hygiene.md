# Spec: Knowledge Hygiene

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo |
| **Status** | Draft |
| **RFC** | N/A |

## Problem Statement

RM-107, the first engine of [Cluster 19](../roadmap.md) (knowledge-root operations), built on the RM-106 registry. A markdown knowledge base decays silently: a context unchanged for 40 days reads as current, a concluded project lingers outside `archive/`, a source becomes orphaned, an internal link rots, a known field (an owner, a status) was never recorded. Today `plan-backlog-hygiene` audits only `docs/` plans and `audit-config` audits the Octopus config surface — neither audits an arbitrary knowledge root, and nothing covers staleness/orphans/coverage uniformly.

`knowledge-hygiene` is a generic audit over any registered knowledge root, consuming the `octopus kr` interface (RM-106). It produces a read-only report by default and applies reversible fixes under `--fix`. Per [ADR-010](../adr/010-knowledge-hygiene-boundary.md) it subsumes the staleness/orphan/link concern of `plan-backlog-hygiene` (which folds in as the `docs/` target, parity-gated), while `audit-config` stays separate.

See [research](../research/2026-05-31-knowledge-root-operations.md) for the cluster motivation.

## Goals

- Audit any knowledge root (selected by `kr` id, default: all resolved roots) for: **staleness** (nodes past the root's `staleness_days`), **orphans** (nodes no other node links to), **broken links** (link targets that don't exist), **archive drift** (concluded items not under the root's `archive_dir`).
- A `--gaps` mode adding documentation-coverage detection: nodes missing a known field, **and** recurring entities that appear across nodes/sources but never got their own node ("what do I talk about and never documented?").
- A severity-tiered, read-only report by default; `--fix` applies **reversible** moves (archive a concluded node, repair a re-homeable link), never destructive edits.
- Touch the filesystem only through `octopus kr` (no direct path/link parsing) — so every root the registry knows works for free.
- Fold `plan-backlog-hygiene` into the `docs/` target, parity-gated, then alias/deprecate it (ADR-010).

## Non-Goals

- Cross-node *synthesis* / connection surfacing — that is `knowledge-synthesize` (RM-108).
- Proactive cadence summaries — that is `knowledge-briefing` (RM-109).
- The consigliere lens (political-risk, playbook voice) over the report — RM-110.
- Auditing the Octopus config surface (model drift, phantom skills) — stays in `audit-config` (ADR-010).
- New link conventions or registry fields — owned by RM-106.

## Design

### Overview

A skill + `octopus`-invokable command that, for each target root, enumerates nodes via `kr nodes`, builds a link graph via `kr links`, reads thresholds/archive via `kr meta`/`kr archive`, runs the five checks, and emits a severity-tiered report. `--fix` replays the subset of findings that have a safe, reversible remedy.

### Detailed Design

**Architecture — hybrid (deterministic core + LLM wrapper).** Following the audit-family pattern (`skills/_shared/audit-pre-pass.md`), the mechanical checks live in a deterministic core `cli/lib/knowledge-hygiene.sh` exposed as `octopus hygiene`; a `skills/knowledge-hygiene/SKILL.md` wraps it for invocation, the fuzzy `--gaps` judgment, and `--fix` confirmation. Rationale: hygiene's checks are mostly mechanical (date arithmetic, link existence, orphan graph, `status:` matching) — those want determinism and unit tests, which the core + `octopus kr` provide; only the fuzzy tail (recurring-entity detection, ambiguous "concluded") needs LLM judgment. The deterministic core is also what makes the ADR-010 parity gate viable: the `docs`-target findings are reproducible, so they can be diffed against `plan-backlog-hygiene`'s.

**Engine shape.** For each target root (`octopus kr list`, or an explicit `--root` id), the core pulls nodes via `kr nodes <id>`, the inbound-link graph via `kr links <id> <node>` over all nodes, and thresholds via `kr meta` / `kr archive`. The checks run over that data; nothing reads paths or parses link syntax directly.

**Checks**

1. **Staleness** — per node, "last updated" via cascade: frontmatter `updated:` → git last-commit (`git log -1 --format=%ct` when the node is in a git tree) → filesystem mtime. Flag if `now − updated > staleness_days` (`kr meta <id> staleness_days`). *sev: warn.*
2. **Broken links** — `kr links` targets that don't exist on disk. *sev: warn.*
3. **Orphans** — nodes with zero inbound links, **excluding** entry patterns (`README*` / `index*` / `roadmap*`) and a per-root `orphan_allowlist`. *sev: info.*
4. **Archive drift** — node whose frontmatter `status:` is in the root's terminal set (default `done,closed,archived`, overridable) and is **not** under `kr archive <id>`. *sev: info; `--fix` moves it.*
5. **`--gaps`** — (a) node missing a per-root required field; (b) recurring untracked entity: a link target / `[[mention]]` that resolves nowhere yet recurs across ≥ `gaps_min_occurrences` nodes. *sev: info.*

**Per-root hygiene config** — shallow scalars in `.octopus.yml` (reusing RM-106's override reader; lists are comma-separated to stay within the scalar contract): `terminal_status`, `orphan_allowlist`, `required_fields`, `gaps_min_occurrences`.

**`--fix` (reversible only).** Acts on archive-drift (move the node into the `kr archive` dir — git-tracked, reversible) and broken links with a single unambiguous re-home target. Everything else stays report-only.

**Report.** Severity-tiered (warn / info), grouped by root → check, matching the existing `audit-*` skills' output conventions.

**plan-backlog-hygiene fold (ADR-010).** Its checks map onto generic ones: orphan plans → orphans, broken internal links → broken links, stale plans → staleness. Its one docs-specific check — *roadmap RM entry without a plan file* — does **not** generalize, so it stays a `docs`-target extension layered on the engine (settled in the fold task). The alias flips only after the `docs` target reproduces the current findings (parity-gated).

### Migration / Backward Compatibility

- New skill + command; additive. `plan-backlog-hygiene` keeps working until the `docs/` target reaches parity (its existing test cases pass through the engine), then it becomes a thin alias and is deprecated (ADR-010).
- Reuses `octopus kr` (RM-106) — no new config surface.

## Implementation Plan

1. Skill scaffold + command dispatch; target selection via `kr list` / explicit id.
2. The five checks, each over the `kr` interface; severity tiering + report format.
3. `--gaps` mode (missing field + recurring untracked entity).
4. `--fix` reversible remedies (archive move, link repair).
5. `plan-backlog-hygiene` parity + fold + alias (ADR-010).
6. Tests: fixture root per check; `--fix` reversibility; parity suite for the `docs/` target.

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [backend-developer, architect]
**Related ADRs**: [ADR-009 (config scoping), ADR-010 (hygiene boundary)]
**Skills needed**: [adr, doc-design, plan-backlog-hygiene (fold donor)]
**Bundle**: introduces the `knowledge-hygiene` skill — adopt into a Cluster 19 bundle (proposed: `knowledge-ops`, shared by RM-107/108/109) or the existing docs/quality bundle; settle in the design session.

**Constraints**:
- Pure bash, no new runtime dependency; all filesystem access via `octopus kr`.
- `--fix` is reversible only — never deletes or rewrites node content destructively.
- Do not duplicate `audit-config`'s domain (ADR-010 boundary).

## Testing Strategy

- Per-check fixtures over a synthetic knowledge root: a stale node (each cascade tier — `updated:`, git, mtime), a broken link, an orphan (and an entry-pattern/allowlist node that must NOT flag), a `status: done` node outside the archive, a node missing a required field, a recurring untracked entity above/below `gaps_min_occurrences`. Assert the report flags exactly the intended nodes.
- `--fix` reversibility: assert an archive-drift move lands the node under `kr archive` and leaves a clean, revertible git change; assert report-only findings are untouched.
- Staleness cascade: a non-git fixture root falls back to mtime; a git fixture uses last-commit; frontmatter `updated:` wins over both.
- Parity suite (gates the ADR-010 alias flip): the `docs` target reproduces `plan-backlog-hygiene`'s current findings on a fixture mirroring its existing test cases.

## Risks

- **Staleness signal portability.** Git-based dating fails on a non-git root (a fresh consigliere workspace); frontmatter dating requires a convention. The design must pick a signal that degrades gracefully per root.
- **Parity regression.** Folding `plan-backlog-hygiene` before the `docs/` target matches its findings would regress a working skill. Mitigation: gate the alias flip on a parity test set (ADR-010).
- **Over-reach of `--fix`.** An automatic archive/relink that misreads "concluded" could move a live node. Mitigation: `--fix` only acts on high-confidence, reversible findings; everything else stays report-only.

## Changelog

- **2026-05-31** — Initial draft (stub pre-filled from Cluster 19 research + ADR-010).
- **2026-05-31** — Design session completed. Settled: staleness cascade (frontmatter→git→mtime), terminal-status archive detection, orphan allowlist. Detailed Design, Testing Strategy, Implementation Plan filled.
- **2026-05-31** — Architecture clarified to **hybrid** (deterministic core `cli/lib/knowledge-hygiene.sh` + `octopus hygiene` + LLM `SKILL.md` wrapper), matching the audit-family pattern rather than a bash-only engine. This keeps ADR-010's parity gate viable (deterministic `docs`-target findings); ADR-010 needs no change.
