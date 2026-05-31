#!/usr/bin/env bash
# tests/test_consigliere_scaffold.sh
# Structural tests for the consigliere workspace scaffold (RM-099).
# Grep-based, per project convention. Covers the templates contract and the
# consigliere-bootstrap SKILL.md (the workspace contract + write-guard + schemas).
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$OCTOPUS_DIR/templates/consigliere"
SKILL="$OCTOPUS_DIR/skills/consigliere-bootstrap/SKILL.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- templates: the contract stubs --------------------------------------
for f in README.md state.md journal.md playbook.md meta.yml gitignore; do
  check "template $f exists" test -f "$T/$f"
done

# --- state.md: the six fixed section headers (the digest contract) -------
for h in "Status by workstream" "Blockers" "Decisions" \
         "System & area map" "Actions" "Political risk"; do
  check "state.md has section '$h'" grep -q "$h" "$T/state.md"
done
check "state.md carries a provenance marker" grep -qE "updated:|sources:" "$T/state.md"

# --- journal.md: append-only + citation anchor convention ---------------
check "journal.md documents the (src: …) citation anchor" grep -q "src:" "$T/journal.md"

# --- meta.yml: the project schema keys ----------------------------------
for k in "title:" "status:" "contexts:" "started:" "due:"; do
  check "meta.yml has key $k" grep -q "$k" "$T/meta.yml"
done

# --- SKILL.md: exists with valid frontmatter ----------------------------
check "consigliere-bootstrap SKILL.md exists" test -f "$SKILL"
check "frontmatter name is consigliere-bootstrap" grep -q "^name: consigliere-bootstrap$" "$SKILL"
check "frontmatter has description" grep -q "^description:" "$SKILL"

# --- SKILL.md: documents the workspace contract -------------------------
for d in "sources/" "contexts/" "projects/" "people/"; do
  check "SKILL documents $d in the layout" grep -q "$d" "$SKILL"
done
check "SKILL documents the state/journal/playbook trio" \
  grep -qiE "state\.md.*journal\.md|trio" "$SKILL"

# --- SKILL.md: the ADR-007 write-guard + config key ---------------------
check "SKILL documents the consigliere.workspace config key" grep -q "consigliere.workspace" "$SKILL"
check "SKILL documents the write-guard (refuse outside workspace)" \
  grep -qiE "write-guard|never writes? outside|refuse[s]? to write outside|outside the (configured )?workspace" "$SKILL"
check "SKILL warns when target looks like a code repo" \
  grep -qiE "code repo|package\.json|\.csproj|looks like" "$SKILL"

# --- SKILL.md: the sources/ frontmatter schema --------------------------
for k in "origin" "kind" "fetched_at"; do
  check "SKILL documents sources frontmatter key '$k'" grep -q "$k" "$SKILL"
done

# --- site docs: both locales (curated voice) ----------------------------
check "site doc (EN) exists" test -f "$OCTOPUS_DIR/docs/site/skills/consigliere-bootstrap.mdx"
check "site doc (pt-br) exists" test -f "$OCTOPUS_DIR/docs/site/pt-br/skills/consigliere-bootstrap.mdx"
check "site doc (EN) documents consigliere.workspace" \
  grep -q "consigliere.workspace" "$OCTOPUS_DIR/docs/site/skills/consigliere-bootstrap.mdx"
check "site doc (EN) surfaces the write-guard / privacy guarantee" \
  grep -qiE "write-guard|never writes? outside|private" "$OCTOPUS_DIR/docs/site/skills/consigliere-bootstrap.mdx"
check "site doc (pt-br) surfaces the write-guard / privacy guarantee" \
  grep -qiE "write-guard|nunca escreve|privad" "$OCTOPUS_DIR/docs/site/pt-br/skills/consigliere-bootstrap.mdx"
check "SKILL marks the write-guard as the canonical contract" \
  grep -qi "canonical write-guard contract" "$SKILL"

# --- summary ------------------------------------------------------------
echo "-----------------------------------------"
echo "consigliere-scaffold: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
