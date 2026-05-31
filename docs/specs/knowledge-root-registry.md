# Spec: Knowledge-Root Registry

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo |
| **Status** | Draft |
| **RFC** | N/A |

## Problem Statement

RM-106, the foundation of [Cluster 19](../roadmap.md) (knowledge-root operations). The three engines that cluster proposes — `knowledge-hygiene` (RM-107), `knowledge-synthesize` (RM-108), `knowledge-briefing` (RM-109) — all operate over a markdown tree, but Octopus has no shared notion of *which* tree, *how it is linked*, *where its archive lives*, or *how stale is stale*. Without a registry each engine would re-implement that, and the fragmentation we already have (`plan-backlog-hygiene` and `audit-config` each hard-code their own scope) would multiply.

A **knowledge root** is a markdown tree with an optional link convention, an optional archive directory, and a staleness threshold. Octopus already has at least four: `docs/`, the standards set (`knowledge/` + `rules/` + `CONTEXT.md`), the auto-memory (`~/.claude/.../memory`, already `[[ ]]`-linked), and the consigliere workspace (`sources/contexts/projects/people`). This spec defines the registry that declares them so RM-107…110 can be written against one abstraction.

See [research](../research/2026-05-31-knowledge-root-operations.md) for the full motivation.

## Goals

- A declarative way to register a knowledge root with: `path`, `link_convention` (`relative` | `wikilink` | `fanout` | `none`), `archive_dir`, `staleness_days`, optional `lens_profile`, optional read-only `source_adapter`.
- Built-in roots shipped out of the box: `docs/`, standards set, auto-memory, consigliere workspace — each with sensible defaults so the engines work with zero extra config.
- A single resolver/loader the engines (RM-107…109) call to enumerate roots and read a root's nodes, links, and archive — no engine touches paths directly.
- Honor the per-root write policy (the consigliere root is bound by the ADR-007 write-guard; other roots declare their own).
- Settle the reconciliation with `plan-backlog-hygiene` and `audit-config` (decision D1 below).

## Non-Goals

- The engines themselves (hygiene / synthesize / briefing) — RM-107…109, separate specs.
- The consigliere lens profile implementation — RM-110; this spec only reserves the `lens_profile` field in the schema.
- New node *types* (e.g. a PARA "Resources" node) — out of scope; the consigliere's existing `contexts`/`sources` cover reference material.
- Any scheduler — cadence for briefing is hosted by `/schedule` / `/loop`, not by the registry.

## Design

### Overview

A registry of root declarations + a loader. Roots come from two layers: **built-in defaults** (shipped with Octopus) and **user/project declarations** (config). The loader merges them, resolves paths (some per-repo, some per-user), and exposes a uniform read interface the engines consume.

### Detailed Design

**Root declaration — two sources, shallow merge.** Built-in roots ship in a defaults file `cli/lib/knowledge-roots.default` (pipe-delimited, one root per line — trivially awk-parsable, no YAML nesting):

```
# id|path|link_convention|archive_dir|staleness_days|lens_profile|write_policy
docs|docs/|relative|docs/plans/archive/|90||rw
standards|knowledge/|none||120||rw
memory|$OCTOPUS_MEMORY_DIR|wikilink||120||rw
consigliere|$CONSIGLIERE_WORKSPACE|fanout|archive/|30|consigliere|adr-007
```

Overrides are **shallow, per-id** in `.octopus.yml` (only the fields a user changes), parsed with the existing awk/grep convention — no nested-list parser:

```yaml
knowledge_roots:
  consigliere:
    staleness_days: 45
  docs:
    staleness_days: 60
```

`$OCTOPUS_MEMORY_DIR` and `$CONSIGLIERE_WORKSPACE` resolve from user-scoped config (`$USER_CONFIG_DIR/.octopus.yml`, the same layer that already holds `consigliere.workspace`). A built-in root whose path variable is unset → omitted from the registry (graceful no-op, never an error).

**Config layering (ADR-009).** Precedence **built-in defaults < project `.octopus.yml` < user `.octopus.yml`**. Load-time guard: an override block under a per-user root id (`memory`, `consigliere`) in the **project** `.octopus.yml` may set scalar fields (e.g. `staleness_days`) but a `path:` key there is rejected — private paths only resolve from user config.

**Read interface — `octopus kr` subcommand** (new `cli/kr.sh`, dispatched by the existing `octopus` entrypoint; engines call it inline, line-oriented output):

| Command | Output |
|---|---|
| `octopus kr list` | one root `id` per line (resolved + present only) |
| `octopus kr meta <id> <field>` | resolved field value (`path`, `link_convention`, `archive_dir`, `staleness_days`, `lens_profile`, `write_policy`) |
| `octopus kr nodes <id>` | absolute path per node file in the root (respecting the node convention; excludes `archive_dir`) |
| `octopus kr links <id> <node>` | resolved outbound link targets of `<node>` per the root's `link_convention` (`relative` path-resolve / `wikilink` `[[name]]`-resolve / `fanout` pointer-resolve / `none` → empty) |
| `octopus kr archive <id>` | absolute archive dir, or empty if the root declares none |

Engines (RM-107…109) touch the filesystem **only** through these commands — they never read a path or parse a link convention themselves. `links` centralizes the one genuinely convention-specific operation so the four link styles live in one place.

**Resolution flow:** `kr` loads defaults → applies project overrides (guard-checked) → applies user overrides → resolves path variables → drops absent roots → answers the query. No caching in v1 (YAGNI).

**Resolved decisions:**

- **D1 — Fold vs keep ([ADR-010](../adr/010-knowledge-hygiene-boundary.md)).** Hybrid: `plan-backlog-hygiene` folds into `knowledge-hygiene` as the `docs/` target view (old skill aliased/deprecated, parity-gated); `audit-config` stays separate (it audits the config surface, a different domain). Rule: "markdown tree decaying" → engine target; "Octopus config wrong" → `audit-config`.
- **D2 — Root config location ([ADR-009](../adr/009-knowledge-root-config-scoping.md)).** Hybrid with guard: per-repo roots in `.octopus.yml`; per-user roots in user config (reusing the `consigliere.workspace` pattern). The schema forbids a private path in `.octopus.yml` by construction — it may reference a per-user root by `id` only. Precedence: built-in < project < user.

### Migration / Backward Compatibility

- Additive for the registry itself. `octopus kr` is a new subcommand and `knowledge_roots:` a new optional `.octopus.yml` block — existing manifests parse unchanged, and a repo with neither still gets the built-in roots.
- Per ADR-010, `plan-backlog-hygiene` folds into the engine's `docs/` target only after parity is reached, then the old skill is aliased/deprecated; `audit-config` is untouched.
- Built-in roots must resolve to no-ops when their path is absent (e.g. no consigliere workspace configured) so the engines degrade gracefully.

## Implementation Plan

1. **Defaults file** — `cli/lib/knowledge-roots.default`: the four built-in roots in pipe-delimited form (`id|path|link_convention|archive_dir|staleness_days|lens_profile|write_policy`).
2. **Loader** — `cli/lib/knowledge-root.sh`: parse defaults (awk), apply shallow per-id overrides from project then user `.octopus.yml` (existing grep/awk convention), resolve `$OCTOPUS_MEMORY_DIR` / `$CONSIGLIERE_WORKSPACE` from user config, drop roots whose path is unset/absent.
3. **Guard** — in the loader, reject a `path:` key under a per-user root id (`memory`, `consigliere`) found in the **project** `.octopus.yml`; scalar overrides there are allowed.
4. **Subcommand** — `cli/kr.sh` exposing `list | meta <id> <field> | nodes <id> | links <id> <node> | archive <id>`; wire into the `octopus` entrypoint dispatch. `links` implements the four `link_convention` resolvers in one place.
5. **Tests** — `tests/test_knowledge_root.sh`: merge precedence (built-in < project < user), path-variable resolution, graceful-absence no-op, guard rejection, and one fixture per `link_convention` for `kr links`.
6. **(Out of scope — RM-107)** the `plan-backlog-hygiene` fold is owned by the RM-107 spec, parity-gated per ADR-010 — not this item.

## Context for Agents

**Knowledge modules**: [architecture, config-loading]
**Implementing roles**: [architect, backend-developer]
**Related ADRs**: [ADR-007 (write-guard, referenced by the consigliere root), ADR-009 (config scoping), ADR-010 (hygiene boundary)]
**Skills needed**: [adr, doc-design]
**Bundle**: N/A — this is a foundation/library item, not a new user-facing skill; the engines (RM-107…109) carry the bundle questions.

**Constraints**:
- Pure bash + existing config plumbing (`.octopus.yml`, user config), no new runtime dependency.
- A registered root that does not exist on disk is a no-op, never an error.
- The consigliere root must remain bound by the ADR-007 write-guard.
- No engine reads filesystem paths directly — only through the loader.

## Testing Strategy

- Unit (`tests/test_knowledge_root.sh`): defaults-file parsing; merge precedence built-in < project < user; path-variable resolution (`$OCTOPUS_MEMORY_DIR` / `$CONSIGLIERE_WORKSPACE`); graceful no-op when a root path is unset/absent; guard rejection of a `path:` under a per-user id in project `.octopus.yml`.
- `octopus kr` contract: `list` shows only resolved+present roots; `meta` returns merged values; `nodes` excludes `archive_dir`; one fixture per `link_convention` (`relative` / `wikilink` / `fanout` / `none`) asserting `kr links` resolves correctly.
- Out of scope here: the `plan-backlog-hygiene` parity/regression suite lives with the RM-107 fold (ADR-010), not this spec.

## Risks

- **Per-user vs per-repo config leak.** Putting a per-user root path in a versioned `.octopus.yml` would leak a private workspace path into the team repo. Mitigated by the ADR-009 load-time guard (reject private paths under a per-user id in `.octopus.yml`) — must be a real check, not just docs.
- **Over-abstraction.** If only two roots ever get real engine usage (auto-memory + consigliere), the registry could be heavier than needed. Mitigation: ship the abstraction minimal; do not build adapters/lens hooks until a consumer exists (YAGNI, per the research's caveat).

## Changelog

- **2026-05-31** — Initial draft (stub pre-filled from Cluster 19 research; Detailed Design + Implementation Plan to be completed in the design session after D1/D2).
- **2026-05-31** — Design session completed. D1/D2 settled (ADR-009/010). Detailed Design (defaults file + shallow overrides, `octopus kr` subcommand, four link-convention resolvers), Implementation Plan, Testing Strategy, and Migration filled.
