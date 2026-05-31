# Spec: consigliere-connect-atlassian

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-31 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-104 (Cluster 17) |
| **Depends on** | RM-100 (`digest-source` consumes Jira/Confluence) |
| **Research** | [2026-05-31-consigliere-workspace](../research/2026-05-31-consigliere-workspace.md) |

## Problem Statement

`digest-source` (RM-100) can read pasted text, PDFs, and Jira (via MCP) today, but
**Confluence** and richer Jira reads need the Atlassian MCP, which is not connected.
Connecting it raises a trust question — the user must authorize an AI agent to read
their Jira/Confluence. The friction is not *how* to trust, but *how many times* the
user must reconfirm. This skill makes the connection a **one-time OAuth consent plus
a pre-shipped read-only guardrail**, so after a single browser approval the consigliere
reads Atlassian with zero repeated prompts and no write capability.

## Goals

1. Connect the **official Atlassian Rovo MCP Server** over **OAuth 2.1** (per-user, no
   static secret) — not an API token — with one guided command.
2. Make it **read-only and prompt-free** by writing a `permissions` allow/deny block to
   `.claude/settings.json` (allow the read tools, deny the write tools).
3. Drive the **one-time consent** (`/mcp` → browser) and **verify** the connection,
   with a clear note that `digest-source` falls back to export-PDF/paste if it is absent.
4. Surface the **trust facts** the user (and their security team) need: per-user OAuth
   scope, revocation path, audit-log visibility.

"Done" = the user runs the skill, approves once in the browser, and `digest-source`
can read Jira + Confluence read-only with no per-call prompts; writes are denied.

## Non-Goals

- Building or hosting an MCP server — this consumes Atlassian's official one.
- Any write to Jira/Confluence — read-only by construction.
- Touching the `consigliere.workspace` data — this skill configures the Claude Code
  environment (`.claude/settings.json` + MCP registration), not the private workspace.
- Data Center / Server self-hosting (note the alternative; do not implement it).

## Design

### Overview

A guided, operator-run setup skill: explain → register the MCP over OAuth → write the
read-only permission guardrail → drive consent → verify. It edits Claude Code config
(`.claude/settings.json`), **not** the workspace.

### Detailed Design

#### Invocation

```
/octopus:consigliere-connect-atlassian
```

#### Step 1 — Explain + confirm

State plainly: this connects the **official Atlassian Rovo MCP Server** (GA) over
**OAuth 2.1**, **per-user** (the agent sees only what you already see in Atlassian),
**read-only**, revocable, and audited. Get the user's go-ahead.

#### Step 2 — Register the MCP (OAuth, user scope)

Run:

```bash
claude mcp add --transport http atlassian --scope user https://mcp.atlassian.com/v1/mcp
```

- `--transport http` — Streamable HTTP (the legacy `/v1/sse` endpoint is deprecated,
  removed after 2026-06-30; do not use it).
- `--scope user` — available across all the manager's repos (not per-project).
- Optionally pin read scopes as defense-in-depth via `claude mcp add-json` with
  `oauth.scopes` = `"read:jira-work read:jira-user read:confluence-content.all
  read:confluence-space.summary offline_access"`.

#### Step 3 — Write the read-only guardrail

Atlassian's read-only **scope pinning does not hide the write tools** (a known gap),
so read-only is enforced on the Claude Code side. Merge (do not clobber) a
`permissions` block into `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": ["mcp__atlassian__getJiraIssue", "mcp__atlassian__searchJiraIssuesUsingJql",
              "mcp__atlassian__getConfluencePage", "mcp__atlassian__searchConfluenceUsingCql"],
    "deny":  ["mcp__atlassian__createJiraIssue", "mcp__atlassian__editJiraIssue",
              "mcp__atlassian__addCommentToJiraIssue", "mcp__atlassian__transitionJiraIssue",
              "mcp__atlassian__createConfluencePage", "mcp__atlassian__updateConfluencePage"]
  }
}
```

The exact tool names are **version-dependent** — run `/mcp` once connected to read the
real list, then reconcile the allow/deny entries. `deny` always beats `allow`.
Allowlisting the read tools is also what removes the per-call permission prompt.

#### Step 4 — Consent + verify

Tell the user to run `/mcp` → approve in the browser (one time; the token auto-refreshes
afterward). Verify with a single read (e.g. fetch one Jira issue). If the server is not
reachable, note that `digest-source` falls back to export-PDF/paste — no hard failure.

#### Step 5 — Trust facts

Surface: revoke anytime from Atlassian profile → **Connected apps** (or org admin
org-wide); MCP actions appear in Atlassian **audit logs**; OAuth keeps no static secret
in config or version control. Read-only + per-user OAuth caps blast radius (incl.
prompt-injection from attacker-authored ticket text).

### Migration / Backward Compatibility

Additive. Adds `consigliere-connect-atlassian` to the `consigliere` bundle. No change
to existing skills; `digest-source`'s existing fallback is unchanged.

## Implementation Plan

1. `skills/consigliere-connect-atlassian/SKILL.md` — author the five-step guided setup.
2. `bundles/consigliere.yml` — add `consigliere-connect-atlassian` to `skills:`.
3. `tests/test_consigliere_connect_atlassian.sh` — structural: frontmatter; OAuth (not
   token); the `mcp.atlassian.com/v1/mcp` Streamable-HTTP endpoint; `--scope user`; the
   read-only allow/deny `permissions` block; the scope-gap rationale; `/mcp` consent;
   verify-tool-names note; export-PDF fallback; revocation/audit.
4. `tests/test_consigliere_bundle.sh` — extend: lists the skill, member exists.
5. `docs/site/skills/consigliere-connect-atlassian.mdx` (+ pt-br, hash in-sync).

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [backend-developer]
**Related ADRs**: [ADR-007, ADR-008]
**Skills needed**: [octopus:scaffold-skill]
**Bundle**: `consigliere (existing)` — adds the optional connector (now 5 skills + 1 role).

**Constraints**:
- Markdown instruction skill; grep-based structural tests; no new deps.
- **OAuth, not API token**; **read-only** enforced via Claude Code `permissions`.
- Edits `.claude/settings.json` + MCP registration — never the private workspace.
- Tool names are version-dependent — verify via `/mcp`, do not hardcode blindly.
- English-only content; generic examples.

## Testing Strategy

Structural (grep) tests asserting the SKILL documents: OAuth over the official
Streamable-HTTP endpoint, `--scope user`, the read-only allow/deny `permissions` block
and the scope-gap reason it is needed, the `/mcp` consent step, the verify-tool-names
caveat, the export-PDF fallback, and the revocation/audit trust facts. Bundle test
extended for the new member.

## Risks

- **Atlassian closes/changes the scope gap or tool names** — mitigated: the skill tells
  the operator to verify via `/mcp` rather than trusting hardcoded names.
- **Endpoint churn** (SSE deprecation) — mitigated: pins the Streamable-HTTP endpoint
  and flags the deprecated one.
- **Over-broad consent** — mitigated: `--scope user` read scopes + deny-writes guardrail.

## Changelog

- **2026-05-31** — Initial draft (RM-104; closes Cluster 17).
