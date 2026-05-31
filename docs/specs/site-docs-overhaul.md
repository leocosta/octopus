# Spec: Site Docs Overhaul — Didactic & Complete

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo |
| **Status** | Draft |
| **RFC** | N/A |

## Problem Statement

The public GitHub Pages docs (Astro/Starlight, EN + `pt-br/`, canonical source in `docs/site/**`) have five gaps:

1. **Implementation leakage** — pages reference internal artifacts a reader should never see (`RM-xxx`, `Cluster Y`, `#PR`, "shipped in vX"). Several SKILL.md `description`s carry these and would re-leak if pulled verbatim.
2. **Thin explanation** — bundles / roles / rules / commands / skills / hooks are not consistently explained with *introduction → what it solves → how it solves*.
3. **Params undocumented** — commands/skills that take flags/args don't detail them.
4. **Roadmap is published** — an internal RM/cluster backlog leaks to users via a site roadmap page.
5. **Incomplete** — the site documents ~25 skills while the repo ships ~60; hooks/bundles also lag; **rules aren't documented at all**.

This spec makes the docs **didactic and complete** without violating the curation principle (rationale is hand-written, never auto-generated).

## Goals

- A **didactic template** per artifact type: a shared spine (Intro → What it solves → How it works) plus type-specific sections.
- **Completeness** — every artifact (skill / command / hook / bundle / role / rule) has an EN + pt-br page, kept complete over time.
- **No implementation leakage** — no `RM-\d+` / `Cluster \d+` / `#\d+` / "shipped in vX" in any published page.
- **Roadmap removed** from the site; the internal `docs/roadmap.md` stays; the changelog remains as "what's new".
- **Rules documented** — a new `rules` collection (one page per family + a layering overview).
- **Both languages stay in sync** — EN canonical, pt-br mirror, no published page left in a `TODO` or stale-translation state.

## Non-Goals

- Editing `site/src/content/docs/` directly — it is generated from `docs/site/**` by `sync-content.sh`.
- Auto-generating the **rationale** prose — only mechanical sections (params tables, bundle membership, frontmatter) are generated; intro/solves/how stay hand-curated.
- Removing the changelog (it is user-facing, not an internal roadmap).
- A marketing redesign / visual overhaul — this is content + IA, not theme.

## Design

### Overview

Edit the canonical tree `docs/site/**`. A permanent, idempotent generator fills the **mechanical** sections of every artifact's page (and strips implementation leakage at the source); the **curated** rationale is hand-written. A deterministic CI/local check enforces completeness, no-leakage, and no-published-`TODO`. The site never shows an unfinished page (`draft: true` until the rationale lands). Work ships in three phases.

### Detailed Design

**Didactic template (per type).** Shared spine for all: **Introduction** (the hook, 1–2 sentences) → **What it solves** (the concrete pain) → **How it works** (the mechanism). Plus:

- **Command / Skill** — **Usage & parameters** (table: flag/arg → what it does → default) + an example.
- **Bundle** — **What's included** (its skills/roles, one line each) + **When to enable**.
- **Role** — **When to invoke** + **What it judges / produces**.
- **Hook** — **When it fires** + **Blocks or signals?**.
- **Rule** — **What it requires** + **How to override** (`.local.md`, extend-only vs override).

**Mechanical vs curated (the hybrid).** Generated deterministically from each artifact: frontmatter (title/description, leakage-stripped), the **Usage & parameters** table (parsed from the SKILL.md `## Invocation` / `## Usage` or the command frontmatter), and a bundle's **What's included** list (from its `.yml`). Hand-curated always: Introduction / What it solves / How it works.

**Generator** `site/scripts/scaffold-docs.sh` (permanent, idempotent):
- **creates** a page only for an artifact with no doc (mechanical sections filled, curated sections as `<!-- TODO: ... -->`, `draft: true`), in EN **and** `pt-br/`;
- **refreshes** only the mechanical sections when an artifact changes;
- **never** overwrites curated prose or flips `draft`.

**No-leakage (three layers).** (1) the generator strips `RM-\d+` / `Cluster \d+` / `#\d+` / "shipped in vX" / PR names when pulling from SKILL.md; (2) `check-docs.sh` fails on those patterns in any non-draft page; (3) a one-time sweep cleans the existing ~25 pages + architecture.

**Roadmap removal.** Delete `docs/site/roadmap.md` + its sidebar entry; fix inbound links (`/roadmap`, `roadmap.md`). The internal `docs/roadmap.md` is untouched. The changelog stays.

**Rules collection.** New `docs/site/rules/` (+ `pt-br/rules/`): one page per family (`coding-style`, `security`, `quality`, `testing`, `patterns`, `exceptions`, `language`) on the rule template, plus an **overview** page explaining the layering/override model (defaults → workspace → personal → project).

**Information architecture.** A **didactic index page** per collection (not an auto-list): "what a skill is / how to choose one", items grouped by purpose. Skills grouped **thematically** in the sidebar via a primary `category` per skill (generator-derived from the dominant bundle, hand-adjustable). A new **"Concepts"** page explains the artifact types (skill vs command vs hook vs role vs rule vs bundle) and how they compose.

**Languages.** EN canonical, `pt-br/` mirror. The generator emits both skeletons; the curated rationale is written EN then translated to pt-br **in the same PR** (per batch), honoring the existing `mark-stale-translation` hook.

**`check-docs.sh`** (deterministic, zero LLM; CI + local) fails when:
1. an artifact lacks an EN **or** pt-br page;
2. a non-draft page contains `RM-\d+` / `Cluster \d+` / `#\d+`;
3. a non-draft page still contains a `TODO` rationale marker.

### Migration / Backward Compatibility

Additive to the site toolchain (`scaffold-docs.sh`, `check-docs.sh`, a CI step). Removes the roadmap page (a deletion users won't miss — the changelog covers "what's new"). `draft: true` keeps the public site clean while completeness lands incrementally. No consumer-repo impact (docs are the published site only).

## Implementation Plan

1. **Phase 1 — Foundation (one PR):** `scaffold-docs.sh` + `check-docs.sh` + the impl-details lint; remove the roadmap page + nav + inbound links; one-time sweep of the existing ~25 pages; document the template in `site/STYLE.md`; wire `check-docs.sh` into CI.
2. **Phase 2 — Scaffold (one PR):** run the generator → every missing page (skills/commands/hooks/bundles/roles/rules) created with mechanical sections filled + curated `TODO`, `draft: true`, EN + pt-br. Add the "Concepts" page + per-collection didactic index shells.
3. **Phase 3 — Content (batched PRs, by category):** fill the curated rationale and flip `draft` off, EN + pt-br per PR — skills (in thematic batches), then roles, hooks, bundles, rules; rewrite the few existing pages that fall short of the template.

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [tech-writer, frontend-developer]
**Related ADRs**: []
**Skills needed**: [adr]
**Bundle**: N/A — site tooling + content, not a user-facing Octopus skill.

**Constraints**:
- Edit only `docs/site/**` (canonical); never `site/src/content/docs/` (generated).
- Pure bash for the generator + check; the check is deterministic (zero LLM).
- Rationale prose is always hand-curated; the generator only owns mechanical sections.
- EN canonical; pt-br mirror in the same PR; honor `mark-stale-translation`.
- No `RM-\d+` / `Cluster \d+` / `#\d+` / "shipped in vX" in any published page.

## Testing Strategy

- `check-docs.sh` is itself the regression gate (completeness + no-leakage + no-published-`TODO`); run in CI and locally.
- Generator fixtures: a synthetic artifact with/without an existing page → asserts create-vs-refresh, leakage stripped, curated prose never overwritten, `draft: true` on new pages, both languages emitted.
- A site production build excludes `draft` pages (verify nothing unfinished ships).

## Risks

- **Curated-content volume.** ~35 missing skill pages × 2 languages is large. Mitigation: phasing + draft-gating + batched content PRs; the generator removes all mechanical toil so only prose remains.
- **Generator clobbering curated prose.** A careless re-run could overwrite hand-written rationale. Mitigation: idempotency is a hard rule (refresh mechanical sections only, never the curated ones) + fixtures asserting it.
- **Thematic `category` drift.** A skill's dominant-bundle category may be wrong. Mitigation: generator proposes, human adjusts; not enforced by the check.

## Changelog

- **2026-05-31** — Initial draft. Design fully resolved via a `grill-me` session (template, hybrid generation, permanent generator, three-layer no-leakage, roadmap removal, rules collection, per-batch bilingual, IA, deterministic check, three-phase rollout).
