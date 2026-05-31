---
name: knowledge-hygiene
description: >
  Audit any registered knowledge root (docs/, the standards set, auto-memory,
  the consigliere workspace) for decay: stale nodes, broken internal links,
  orphans, and concluded items that drifted outside their archive. The
  deterministic checks run in `octopus hygiene` over the RM-106 `octopus kr`
  registry; this skill wraps them with the fuzzy `--gaps` judgment (recurring
  untracked entities, missing fields) and `--fix` confirmation. Read-only by
  default; `--fix` applies reversible moves only.
triggers:
  paths: ["docs/**", "knowledge/**", "CONTEXT.md"]
  keywords: ["hygiene", "stale", "orphan", "broken link", "archive", "knowledge root"]
  tools: []
---

# /octopus:knowledge-hygiene

## Purpose

Keep a markdown knowledge base from decaying silently. Stale state read as
current is worse than none. This skill audits a **knowledge root** — any linked
markdown tree the [RM-106 registry](../../docs/specs/knowledge-root-registry.md)
knows — and reports what rotted, optionally fixing the reversible cases.

The mechanical checks are deterministic and live in the `octopus hygiene`
core, which reads nodes, links, thresholds, and the archive dir from
`octopus kr`. This skill adds the judgment the core can't make.

## Invocation

```
/octopus:knowledge-hygiene [--root <id>] [--gaps] [--fix] [--write-report]
```

- `--root <id>` — audit one root (e.g. `docs`, `memory`, `consigliere`); default: every resolved root.
- `--gaps` — also run the documentation-coverage judgment (see Gaps Mode).
- `--fix` — apply the reversible remedies (see Fix Mode); default is report-only.
- `--write-report` — write the report to a file instead of stdout.

Run the deterministic core directly with `octopus hygiene [--root <id>] [--gaps] [--fix]`.

## Hygiene Checks

Each finding is one line: `sev|root|check|node|detail`.

- **staleness** (`warn`) — node's last update (frontmatter `updated:` → git last-commit → mtime) is older than the root's `staleness_days`.
- **broken-link** (`warn`) — a link target (`octopus kr links`) that does not exist on disk.
- **orphan** (`info`) — node with no inbound links, excluding entry patterns (`README*`/`index*`/`roadmap*`) and the root's `orphan_allowlist`.
- **archive-drift** (`info`) — node whose frontmatter `status:` is terminal (`terminal_status`, default `done,closed,archived`) but still lives outside the root's archive dir.

## Gaps Mode

`--gaps` adds documentation-coverage detection — the judgment the core defers to you:

- **missing field** — a node missing a per-root `required_fields` entry (e.g. a project node with no owner).
- **recurring untracked entity** — a `[[mention]]` or link target that resolves nowhere yet recurs across ≥ `gaps_min_occurrences` nodes ("what do I talk about and never documented?"). Read the recurring broken targets from the core's output, judge which are real topics deserving their own node, and report them.

## Fix Mode

`--fix` is **reversible only**:

- **archive-drift** → `git mv` the concluded node into the root's archive dir (history preserved, revertible with `git restore`/`git checkout`).
- **broken-link** → repair only when a single unambiguous re-home target exists.

Everything else stays report-only. Show the staged moves and let the user commit or revert.

## Per-root Configuration

Shallow scalars under `knowledge_roots:` in `.octopus.yml` (comma-separated lists): `terminal_status`, `orphan_allowlist`, `required_fields`, `gaps_min_occurrences`.

## Relationship to plan-backlog

`plan-backlog`'s generic checks (orphan / broken-link / stale plans) are subsumed by this skill's `docs` target (ADR-010); its docs-specific *roadmap-entry-without-plan* check remains its own. See `skills/plan-backlog/SKILL.md`.
