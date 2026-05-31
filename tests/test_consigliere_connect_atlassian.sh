#!/usr/bin/env bash
# tests/test_consigliere_connect_atlassian.sh
# Structural tests for the consigliere-connect-atlassian skill (RM-104). Grep-based.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/consigliere-connect-atlassian/SKILL.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- exists + frontmatter -----------------------------------------------
check "SKILL.md exists" test -f "$SKILL"
check "frontmatter name is consigliere-connect-atlassian" \
  grep -q "^name: consigliere-connect-atlassian$" "$SKILL"
check "frontmatter has description" grep -q "^description:" "$SKILL"

# --- OAuth over the official Streamable-HTTP endpoint --------------------
check "uses OAuth, not API token" grep -qiE "OAuth" "$SKILL"
check "prefers OAuth over a static token" \
  grep -qiE "not an? .*token|no static secret|over .*token|instead of .*token" "$SKILL"
check "official Atlassian (Rovo) MCP server" grep -qiE "Rovo|official Atlassian" "$SKILL"
check "pins the v1/mcp Streamable-HTTP endpoint" grep -q "mcp.atlassian.com/v1/mcp" "$SKILL"
check "flags the deprecated SSE endpoint" grep -qiE "/v1/sse|deprecated|Streamable" "$SKILL"
check "registers via claude mcp add --transport http" \
  grep -qE "claude mcp add.*--transport http" "$SKILL"
check "uses --scope user" grep -qE "\-\-scope user" "$SKILL"

# --- read-only guardrail (the friction-killer) --------------------------
check "writes a permissions allow/deny block" grep -qiE "permissions|allow|deny" "$SKILL"
check "allows read tools, denies write tools" \
  grep -qiE "mcp__atlassian__" "$SKILL"
check "explains the scope-gap rationale" \
  grep -qiE "scope.gap|does not hide|do not (hide|suppress)|write tools (still )?(appear|exposed)|enforce.*Claude Code" "$SKILL"
check "edits .claude/settings.json, not the workspace" \
  grep -qE "\.claude/settings\.json" "$SKILL"

# --- consent + verify + fallback ----------------------------------------
check "drives one-time /mcp consent" grep -qiE "/mcp|browser|consent|one-time" "$SKILL"
check "tells operator to verify tool names via /mcp" \
  grep -qiE "version-dependent|verify.*tool name|run .*/mcp.*(confirm|list)" "$SKILL"
check "notes the export-PDF fallback" grep -qiE "export.*pdf|fallback|paste" "$SKILL"

# --- trust facts --------------------------------------------------------
check "documents revocation" grep -qiE "revoke|revocation|connected apps" "$SKILL"
check "documents audit visibility" grep -qiE "audit log|auditable|audit" "$SKILL"
check "per-user least-privilege (sees only what you see)" \
  grep -qiE "per-user|only what you (can )?see|least privilege|your existing" "$SKILL"

# --- site docs ----------------------------------------------------------
check "site doc (EN) exists" test -f "$OCTOPUS_DIR/docs/site/skills/consigliere-connect-atlassian.mdx"
check "site doc (pt-br) exists" test -f "$OCTOPUS_DIR/docs/site/pt-br/skills/consigliere-connect-atlassian.mdx"

# --- summary ------------------------------------------------------------
echo "-----------------------------------------"
echo "consigliere-connect-atlassian: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
