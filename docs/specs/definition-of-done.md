# Spec: definition-of-done

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-30 |
| **Author** | Leonardo |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-091 (Cluster 16) |

## Problem Statement

"Done" is implicit and scattered today — fragments live in `doc-prd`, `triage-issues`, and the `architect` approval criteria. There is no **team Definition of Done as a first-class, versioned artifact**. That means the bar for "ready to merge / ready to ship" lives in the manager's head and gets applied inconsistently. Making it an artifact lets every engineer's agent check against the same explicit contract.

## Goals

- A first-class **DoD artifact** (a document type under `docs/`, like ADRs) that states the team's done criteria explicitly.
- A skill `definition-of-done` that **creates/updates** the DoD (template-driven) and **validates** a change against it.
- The `codereview` flow consults the DoD so "is this done?" becomes a checked contract, not a judgment call.
- Registered in the `tech-lead` bundle (RM-096).

## Non-Goals

- Not a replacement for the audits/roles — the DoD *references* them ("security audit passes", "ADR exists for irreversible decisions"), it doesn't reimplement them.
- Not per-feature acceptance criteria (that stays in `doc-prd`) — the DoD is the **team-wide baseline** every change meets.
- Not a blocking CI gate by itself (it informs `codereview`; hard blocking stays with hooks/roles).

## Design

### Overview

A versioned `docs/definition-of-done.md` (single source, optionally per-area via sub-context) authored from a template, plus a skill that creates it and validates a diff/PR against its checklist. The DoD becomes the explicit encoding of "our done", consumed by humans and by the `codereview` flow.

### Detailed Design

**The artifact (`docs/definition-of-done.md`):** a checklist grouped by concern, each item phrased as a checkable statement with a pointer to what enforces it. Example shape:

- **Tested** — behavior covered; critical paths have integration tests. (→ `rules/common/testing.md`)
- **Reviewed** — passes `architect`; security-sensitive diffs pass `security`. (→ roles)
- **Documented** — irreversible decisions have an ADR; public API changes update docs. (→ `doc-adr`)
- **Grounded** — no invented conventions / unsupported domain facts. (→ `audit-grounding`)
- **Clean** — formatter + type check pass; no debug statements; no `--no-verify`. (→ `guardrails` hooks)
- **Released safely** — money/tenant/contract concerns audited when touched. (→ `audit-*`)

**The skill (`skills/definition-of-done/SKILL.md`):**
- **create/update mode:** scaffolds `docs/definition-of-done.md` from the template; grills the manager to fill team-specific items (like `doc-design` fills a spec).
- **validate mode:** given a diff/PR, walks the DoD checklist and reports which items are met / unmet / not-applicable — signal, with pointers to the skill or role that closes each gap.

**Integration with `codereview`:** the codereview orchestrator gains a step that runs DoD validation as part of its report, so the consolidated self-review answers "done per our DoD?" alongside the audit findings.

### Migration / Backward Compatibility

Additive. Without a `docs/definition-of-done.md`, the validate step is a no-op that suggests creating one. Existing review flow unchanged until the DoD exists.

## Implementation Plan

1. `templates/definition-of-done.md` — the checklist template (concern groups + enforcement pointers).
2. `skills/definition-of-done/SKILL.md` — create/update + validate modes; frontmatter (cues; `triggers.keywords`: "definition of done", "is this done", "done criteria", "ready to merge"); Anti-Patterns (don't reimplement audits; don't gate); Integration (`codereview`, `doc-adr`, `architect`, `audit-*`).
3. Wire the validate step into the `codereview` skill (additive; no-op when DoD absent).
4. Register in `bundles/tech-lead.yml` (RM-096); interim `bundles/docs.yml`.
5. `tests/test_definition_of_done.sh` — grep-structural: template exists, skill declares create+validate modes, references the enforcing roles/skills, declares signal-not-gate, codereview wiring present.
6. Docs site: `docs/site/skills/definition-of-done.mdx` + pt-br pair; skills index rows (EN + pt-br).

## Context for Agents

**Knowledge modules**: [documentation]
**Implementing roles**: [tech-writer]
**Related ADRs**: N/A
**Skills needed**: [scaffold-skill, doc-design]
**Bundle**: `docs (existing)` interim; `tech-lead (proposed, RM-096)` final
**Constraints**:
- The DoD references existing enforcement; it never reimplements an audit/role.
- Validate is signal-only; hard blocking stays with hooks/roles.
- Markdown skill + template + grep-based bash test; pt-br site pair with source_hash.

## Testing Strategy

- Structural grep test (above).
- Scenario check: `create` scaffolds the template and fills team items; `validate` against a diff missing tests reports the "Tested" item unmet with a pointer to `test-tdd`/`testing.md`.

## Risks

- **Becomes a stale checklist nobody reads:** mitigated by wiring `validate` into `codereview` so it's exercised every self-review, not a shelf document.
- **Duplicates `architect` approval criteria:** mitigated — the DoD is the *contract*; `architect` is one *enforcer* of it. The DoD points at the role rather than restating it.

## Changelog

- **2026-05-30** — Initial draft.
