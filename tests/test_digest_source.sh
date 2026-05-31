#!/usr/bin/env bash
# tests/test_digest_source.sh
# Structural tests for the digest-source skill (RM-100). Grep-based, per convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/digest-source/SKILL.md"
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
check "digest-source SKILL.md exists" test -f "$SKILL"
check "frontmatter name is digest-source" grep -q "^name: digest-source$" "$SKILL"
check "frontmatter has description" grep -q "^description:" "$SKILL"

# --- the four source kinds ----------------------------------------------
for k in "text" "pdf" "jira" "confluence"; do
  check "documents source kind '$k'" grep -qi "$k" "$SKILL"
done

# --- snapshot-first immutability + frontmatter schema -------------------
check "documents the sources/ snapshot path" grep -qE "sources/[A-Z]*Y*Y*Y*Y*/?|sources/YYYY/MM" "$SKILL"
check "snapshot is immutable" grep -qiE "immutable|never edited|never (be )?edit" "$SKILL"
for fk in "origin" "kind" "fetched_at"; do
  check "documents frontmatter key '$fk'" grep -q "$fk" "$SKILL"
done

# --- routing: infer -> confirm -> on-the-fly ----------------------------
check "documents inferred routing from the description" grep -qiE "infer|inferr" "$SKILL"
check "routing confirmed, not silent" grep -qiE "confirm" "$SKILL"
check "on-the-fly node creation under confirmation" grep -qiE "on-the-fly|does not exist|ask before creating|create" "$SKILL"
check "ambiguity asks, never guesses" grep -qiE "ambigu|never guess|when unsure" "$SKILL"

# --- grounding ----------------------------------------------------------
check "documents the (src: …) grounding anchor" grep -q "src:" "$SKILL"
check "strict grounding: never assert what is not in the source" \
  grep -qiE "never (assert|invent)|only what is explicit|not in the (snapshot|source)" "$SKILL"
check "reuses audit-grounding" grep -qi "audit-grounding" "$SKILL"

# --- preview-before-write -----------------------------------------------
check "previews writes before touching disk" grep -qiE "preview" "$SKILL"

# --- write model: journal + state + fan-out -----------------------------
check "appends to journal.md" grep -qi "journal.md" "$SKILL"
check "rewrites materialized state.md" grep -qi "state.md" "$SKILL"
check "fan-out pointer into crossed contexts" grep -qiE "fan-out|pointer" "$SKILL"

# --- write-guard citation + confluence fallback -------------------------
check "cites the write-guard contract (RM-099)" grep -qiE "write-guard|consigliere.workspace" "$SKILL"
check "Confluence fallback when MCP absent" grep -qiE "export.*pdf|fallback|RM-104|paste" "$SKILL"

# --- site docs: both locales --------------------------------------------
check "site doc (EN) exists" test -f "$OCTOPUS_DIR/docs/site/skills/digest-source.mdx"
check "site doc (pt-br) exists" test -f "$OCTOPUS_DIR/docs/site/pt-br/skills/digest-source.mdx"
check "site doc (EN) surfaces grounding" \
  grep -qiE "ground|src:|snapshot" "$OCTOPUS_DIR/docs/site/skills/digest-source.mdx"

# --- summary ------------------------------------------------------------
echo "-----------------------------------------"
echo "digest-source: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
