# Spec: Social Media Role

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-04 |
| **Author** | Codex |
| **Status** | Implemented |
| **RFC** | N/A |
| **Roadmap** | RM-038 |

## Problem Statement

Octopus already provides specialized roles for product, engineering, and
documentation work, but it does not provide a first-class role for social media
operations. Teams that want to turn launches, release notes, campaigns, and
product narratives into social content currently have to use generic agents or
ad hoc prompts, which leads to inconsistent copy, weak channel adaptation, and
unclear publishing safety.

We need a role that can operate as a social media specialist with a strong
copywriting bias, while remaining compatible with the Octopus architecture:
roles provide strategy and content structure, commands automate project tasks,
and MCP or external adapters provide integrations.

## Goals

- Add a reusable `social-media` role to `octopus/roles/`
- Support `X`, `Instagram`, `both`, or unspecified destination flows
- Make destination platform optional in the brief while still producing
  platform-specific output
- Support content planning for `feed`, `carousel`, `story`, `reel`, `thread`,
  and `single post`
- Enforce approval-gated publishing guidance
- Document a template-first approach for visual content generation

## Non-Goals

- Implement real publishing adapters in this change
- Add a production-ready MCP server for `X` or `Instagram`
- Add scheduling, analytics, or inbox-management workflows
- Add image or video rendering code
- Guarantee that any platform integration is fully supported without platform
  credentials, app review, and destination-specific setup

## Design

### Overview

The feature is a new role plus repository documentation. The role defines how a
social-media specialist should reason about audience, claims, platform fit,
asset planning, and approval-gated publishing. The supporting spec documents
how teams should combine the role with integrations later.

The design intentionally separates:
- content strategy and copywriting
- asset briefing
- approval workflow
- publish integrations

This follows the existing Octopus pattern where roles define responsibility and
behavior, while integrations and workflow mechanics live elsewhere.

### Detailed Design

#### Role behavior

The `social-media` role should:
- treat campaign objective, audience, and offer as first-class inputs
- treat destination platform as optional
- produce separate variants when the destination is not specified
- adapt copy structure to `X` versus `Instagram`
- generate structured output for `feed`, `carousel`, `story`, `reel`, and
  `thread`
- distinguish approved facts from inferred or unapproved claims
- refuse implicit publishing and require explicit approval

#### Destination handling

The role must support four routing modes:
- `X`: generate only X-appropriate output
- `Instagram`: generate only Instagram-appropriate output
- `both`: generate distinct variants for both platforms
- unspecified: generate candidate variants for both and explain the fit of each

This keeps the role useful even when the user only asks for "a post" and has
not chosen a final channel yet.

#### Visual content model

Visual formats should be generated as structured briefs, not as raw prompts.
The role should assume:
- feed posts and carousels are best produced from reusable templates
- reels and stories are best produced from scripted scene or frame plans
- asset generation may use design tools, HTML/CSS renderers, Figma/Canva APIs,
  image generation, Remotion, or ffmpeg outside the role itself

The role therefore outputs:
- captions and copy
- slide or scene sequence
- on-screen text
- asset requirements
- CTA
- cover guidance when relevant

#### Publishing architecture

The recommended architecture is:
1. brief ingestion
2. copy and asset brief generation
3. human review
4. explicit approval
5. publish payload preparation
6. destination-specific publishing integration

For future integrations:
- `X` can use an MCP server or a direct adapter, subject to maintenance and
  security review
- `Instagram` should prioritize the official Meta API over scraping or
  unofficial browser-session automation

### Migration / Backward Compatibility

This change is additive. Existing roles, commands, and MCP configuration remain
unchanged.

Projects that want this role must opt in by adding `social-media` to the
`roles:` list in `.octopus.yml` and re-running `octopus setup`.

## Implementation Plan

1. Add `octopus/roles/social-media.md` with frontmatter, `{{PROJECT_CONTEXT}}`,
   platform guidance, quality gates, and approval-gated publishing rules.
2. Add this spec at `docs/specs/social-media-role.md` to document the design,
   scope, and future integration model.
3. Update `README.md` to list `social-media` as an available role and explain
   how it fits the roles and MCP model.
4. Update `knowledge/documentation/knowledge.md` and
   `knowledge/documentation/hypotheses.md` to record the new documentation
   learning from this role addition.

## Context for Agents

**Knowledge modules**: `[documentation]`  
**Implementing roles**: `[tech-writer]`  
**Related ADRs**: `[N/A]`  
**Skills needed**: `[continuous-learning]`

**Constraints**:
- Keep all new repository artifacts in English
- Do not imply that publishing integrations are implemented if they are not
- Preserve the Octopus role pattern: role behavior stays separate from runtime
  integrations
- Treat visual social content as template-first, not prompt-only

## Testing Strategy

- Verify that `social-media.md` can be delivered by the existing generic role
  generation path without setup changes
- Verify that README references to available roles remain accurate
- Verify that the spec and role are fully in English
- Rely on existing role-generation tests for the shared delivery mechanism

## Risks

- Users may assume the role alone provides working social API integrations
- Users may conflate content generation with automatic publishing authority
- The repository may later need a clearer distinction between social planning,
  asset production, and publishing adapters
- Platform-specific guidance may drift as X and Meta APIs evolve

## Changelog

- **2026-04-04** — Initial draft
