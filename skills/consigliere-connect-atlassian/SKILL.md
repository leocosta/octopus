---
name: consigliere-connect-atlassian
description: >
  One-time OAuth 2.1 setup connecting the Atlassian Rovo MCP server to Claude
  Code so digest-source can read Jira and Confluence (read-only). Registers
  the endpoint at user scope, writes a read-only allow/deny block to
  .claude/settings.json, drives browser consent via /mcp, verifies. Edits
  Claude config, never the workspace. Manual; optional consigliere connector.
triggers:
  keywords: ["connect atlassian", "connect jira", "connect confluence", "atlassian mcp", "set up jira for consigliere", "read confluence"]
---

# Connect Atlassian (read-only)

## Overview

`digest-source` reads pasted text, PDFs, and Jira today; **Confluence** and
richer Jira reads need the Atlassian MCP. Connecting it raises a trust question — you
are authorizing an agent to read your Jira/Confluence. The friction is not *how* to
trust but *how many times* you reconfirm. This skill makes it **one OAuth consent plus
a pre-shipped read-only guardrail**: after a single browser approval the consigliere
reads Atlassian with no per-call prompts and **cannot write**.

It configures **Claude Code** (`.claude/settings.json` + MCP registration) — it never
touches the private `consigliere.workspace`.

## When to Engage

Manual, operator-run. Engage once to enable Confluence + richer Jira for the
consigliere. Optional — without it, `digest-source` still works via export-PDF/paste.

## Invocation

```
/octopus:consigliere-connect-atlassian
```

## Step 1 — Explain + confirm

State plainly and get the go-ahead: this connects the **official Atlassian Rovo MCP
Server** (GA) over **OAuth 2.1**, **per-user** — the agent sees **only what you can
already see** in Atlassian Cloud — **read-only**, revocable, and audited. No API token,
**no static secret** in config or version control.

## Step 2 — Register the MCP (OAuth, user scope)

```bash
claude mcp add --transport http atlassian --scope user https://mcp.atlassian.com/v1/mcp
```

- `--transport http` — the **Streamable-HTTP** endpoint. The legacy `…/v1/sse` endpoint
  is **deprecated** (removed after 2026-06-30) — do not use it.
- `--scope user` — available across all your repos, not just this one.
- Defense-in-depth (optional): pin read scopes with `claude mcp add-json … "oauth":
  {"scopes":"read:jira-work read:jira-user read:confluence-content.all
  read:confluence-space.summary offline_access"}`.

## Step 3 — Write the read-only guardrail

Atlassian's read scopes **do not hide the write tools** (a known scope-gap), so
read-only is **enforced on the Claude Code side**. Merge — do not clobber — a
`permissions` block into `.claude/settings.json`, allowing the read tools and denying
the write tools:

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

Allowlisting the read tools is also what removes the **per-call permission prompt** —
this is the friction-killer. `deny` always beats `allow`.

> The exact tool names are **version-dependent**. Run `/mcp` once connected to read the
> real tool list this server version exposes, then reconcile the allow/deny entries —
> do not trust the names above blindly.

## Step 4 — Consent + verify

Tell the user to run `/mcp` → approve in the **browser** (one time; the token
auto-refreshes afterward — no re-consent unless you revoke or widen scopes). Verify
with a single read (fetch one Jira issue). If the server is unreachable, note that
`digest-source` **falls back to export-PDF/paste** — no hard failure.

## Step 5 — Trust facts

- **Revoke** anytime: Atlassian profile → **Connected apps** (or an org admin revokes
  org-wide). In Claude Code, `/mcp` → *Clear authentication* drops the local token.
- **Audit:** MCP actions appear in Atlassian **audit logs** — you can trace what was read.
- **Least privilege:** per-user OAuth caps the agent at your existing visibility; the
  read-only guardrail bounds blast radius (incl. prompt-injection from attacker-authored
  ticket/page text).

## Anti-patterns

- Using an **API token** for an interactive user — prefer OAuth (no static secret).
- Trusting read scopes alone to be read-only — also write the `deny` guardrail.
- Hardcoding tool names without verifying via `/mcp`.
- Writing any of this into the private workspace — it is Claude Code config only.

## Related

- Unblocks `digest-source` for Confluence + richer Jira; the export-PDF
  fallback stays for when this is not connected.
