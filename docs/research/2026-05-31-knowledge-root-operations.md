# Research — Knowledge-root operations (briefing / synthesize / hygiene)

- **Date:** 2026-05-31
- **Author:** Leonardo (Tech Manager II, ex-Staff SWE)
- **Roadmap:** seeds **Cluster 19** (RM-106 … RM-110)
- **Context:** While scoping proactive/synthesis/maintenance skills for the consigliere workspace (Cluster 17), the realization: those three capabilities are **not manager-specific**. "Summarize a base on a cadence", "surface connections that cross nodes", and "audit staleness/orphans/archive" are operations over *any linked markdown tree*. Octopus already has several such trees and already does fragments of this work in scattered, single-purpose skills. The right move is one **generic engine parameterized by a knowledge root**, with the consigliere workspace as one target that adds its lens — not three more consigliere-prefixed skills.

---

## The knowledge roots Octopus already has

A **knowledge root** = a markdown tree with an optional link convention, an optional archive dir, and a staleness threshold. Octopus has at least four:

| Root | Link convention | Existing coverage | Gap |
|---|---|---|---|
| `docs/` (specs, research, ADR, plans, roadmap) | cross-doc relative links | `plan-backlog-hygiene` (plans only), `audit-config` | no briefing, no cross-doc synthesis, hygiene only on plans |
| `knowledge/` + `rules/` + `CONTEXT.md` | implicit (glossary, ADR refs) | `audit-grounding`, `doc-align` | no staleness/orphan audit, no synthesis |
| auto-memory (`~/.claude/.../memory`, `MEMORY.md`) | `[[name]]` backlinks | — | nothing surfaces forgotten-relevant memory; no staleness audit |
| consigliere workspace (`sources/contexts/projects/people`) | fan-out pointers | RM-099…104 (capture + consult) | the proactive/synthesis/maintenance layer (the whole reason this research exists) |

**Key observation — hygiene is already fragmented.** `plan-backlog-hygiene` and `audit-config` each do a slice of staleness/orphan/broken-link checking for the team repo. A separate `consigliere-hygiene` would be a third near-duplicate. The DRY rule in `rules/common/coding-style.md` (three occurrences before extracting) is exactly met: extract one engine.

## Engine vs lens

The engine is generic. What is *not* generic is the **lens** a root may attach to the output:

- The **consigliere lens** — political-risk reading, the per-node `playbook.md` heuristics, the "thinks like you" voice, the ADR-007 write-guard. A briefing over `docs/` has none of these.

So: **engine global, parameterized by root; lens is a per-root profile applied on top.** The consigliere becomes a registered root with a lens profile, not the owner of the skills.

---

## Items

### RM-106 — knowledge-root abstraction (foundation)

**Need:** a config-declared registry of knowledge roots. Each root declares: path, link convention (relative links / `[[ ]]` / fan-out pointers / none), archive dir, staleness threshold, optional lens profile, optional source adapter (e.g. an external Obsidian vault, mirroring `consigliere-connect-atlassian`'s read-only pattern). Built-in roots: `docs/`, the standards set, auto-memory, the consigliere workspace.

**Problem it solves:** without a shared root abstraction the three engines below would each re-implement "what tree, how is it linked, where is archive" — the same fragmentation that already exists across `plan-backlog-hygiene` / `audit-config`. Foundation for RM-107…110.

### RM-107 — `knowledge-hygiene` skill (generic maintenance)

**Need:** staleness + coverage + broken-link + archive audit over a target root. Flags: nodes past the staleness threshold, concluded items not yet in `archive/`, orphaned files, broken internal links, nodes missing a known field. A `--gaps` mode adds documentation-coverage detection — nodes missing a known field *and* recurring entities that appear across journals/sources but never got their own node ("what do I talk about and never documented?"). Read-only report + reversible `--fix`.

**Problem it solves:** every knowledge base decays silently; stale state read as current is worse than none — and undocumented topics stay invisible. Subsumes the staleness/orphan/link concern that `plan-backlog-hygiene` and `audit-config` cover partially — those become a `docs/` target view of this engine (reconcile in the RM-107 spec; don't ship a third silo). The `--gaps` mode is the article's "Knowledge Gap Finder" workflow, kept as a mode rather than a separate skill.

### RM-108 — `knowledge-synthesize` skill (cross-node traversal)

**Need:** surface connections that cross nodes of a root — a shared blocker, a doc that contradicts an ADR, a forgotten-but-relevant past note for a current question. Where a root lacks navigable links, this also seeds/repairs the link convention.

**Problem it solves:** the value of a knowledge base is the IA traversing it and finding links manual recall misses. Today every root is a silo (auto-memory has `[[ ]]` but nothing reads it for relevance; `docs/` specs don't get checked against ADRs unless `doc-align` is run by hand). Highest-leverage target: auto-memory (built to be linked) and `docs/` (specs vs ADRs).

### RM-109 — `knowledge-briefing` skill (proactive output)

**Need:** a generated summary over a target root on a cadence, without the user formulating a question. `--daily` = attention-needed deltas; `--weekly` = a rollup synthesizing recent changes. Read-only, grounded; cadence hosted by `/schedule` or `/loop`, no scheduler inside the skill.

**Problem it solves:** a knowledge base only speaks when spoken to. Nothing surfaces "here's what changed / what needs you today". Strongest targets: the consigliere workspace (cross-context attention) and `docs/`+roadmap (what moved this week). Weakest: standards set — likely a target nobody schedules, so do not build it until asked (YAGNI).

### RM-110 — consigliere lens profile (the consigliere as a root)

**Need:** register the private workspace as a knowledge root (link convention = fan-out pointers, archive dir, staleness threshold) and attach the **consigliere lens profile** — political-risk surfacing, per-node `playbook.md` application, the "thinks like you" voice — so RM-107…109 output, when target = workspace, reads like the consigliere rather than a generic report. Honors the ADR-007 write-guard.

**Problem it solves:** delivers the original Cluster 17 intent (proactive/synthesis/maintenance for the manager) by *reusing* the generic engines instead of duplicating them, while keeping the manager-specific judgment that does not belong in a generic skill.

---

## Build order

RM-106 (abstraction) → RM-107 / RM-108 / RM-109 (engines, independent of each other) → RM-110 (consigliere lens, depends on the engines + RM-099…104). Per-target: prioritize the targets with real demand (auto-memory + consigliere workspace + `docs/`); defer low-demand targets behind explicit need.

## Reuse / reconciliation

- `plan-backlog-hygiene`, `audit-config` — overlapping staleness/orphan/link logic; the RM-107 spec must decide *fold-as-target* vs *keep-specialized*, not silently duplicate.
- `audit-grounding` (RM-088) — strict grounding on every generated claim across all three engines.
- `doc-align` — donor for the synthesis "X contradicts ADR-Y" check.
- `/schedule`, `/loop` — cadence host for RM-109.
- `consigliere-connect-atlassian` (RM-104) — pattern donor for RM-106 external source adapters (e.g. an Obsidian vault as a read-only root).
- ADR-007 write-guard — enforced by the consigliere lens profile (RM-110); other roots declare their own write policy.
