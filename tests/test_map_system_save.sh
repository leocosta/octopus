#!/usr/bin/env bash
# tests/test_map_system_save.sh
# Structural tests for map-system complete mode + themed HTML deck (RM-098).
# Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/map-system/SKILL.md"
THEMES="$OCTOPUS_DIR/skills/launch-release/templates/themes"
DECK_TMPL="$OCTOPUS_DIR/skills/map-system/templates/deck.html.tmpl"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- the three axes -----------------------------------------------------
check "declares --mode simplified|complete" grep -qiE "\-\-mode" "$SKILL"
check "mentions simplified mode" grep -qi "simplified" "$SKILL"
check "mentions complete mode" grep -qi "complete" "$SKILL"
check "default mode is complete" grep -qiE "default.*complete|complete.*default|new default" "$SKILL"
check "declares --save / --no-save" grep -qE "\-\-save|\-\-no-save" "$SKILL"
check "save is on by default" grep -qiE "default.*save|save.*default|saves by default|save on" "$SKILL"
check "declares --output markdown|html" grep -qE "\-\-output" "$SKILL"
check "output default is html" grep -qiE "default.*html|html.*default" "$SKILL"
check "declares --theme with default dark-blue" grep -qi "dark-blue" "$SKILL"

# --- composition --------------------------------------------------------
check "composes frontend-design" grep -qi "frontend-design" "$SKILL"
check "reuses launch-release theme system" grep -qi "launch-release" "$SKILL"
check "reuses audit-contracts for API detection" grep -qi "audit-contracts" "$SKILL"

# --- deck content -------------------------------------------------------
check "deck section: overview / business insights" grep -qiE "business insight|overview" "$SKILL"
check "deck section: architecture / diagrams" grep -qiE "architecture|diagram|mermaid" "$SKILL"
check "deck section: contracts (API)" grep -qiE "contract" "$SKILL"
check "deck section: decisions / ADRs" grep -qiE "ADR|decisions of record" "$SKILL"

# --- mode discipline ----------------------------------------------------
check "simplified keeps the anti-crawl discipline" grep -qiE "sample, do not crawl|do not crawl|one screen|~?30" "$SKILL"
check "complete is allowed to crawl exhaustively" grep -qiE "exhaustive|crawl" "$SKILL"

# --- output + degradation ----------------------------------------------
check "default saved path docs/system-map" grep -q "docs/system-map" "$SKILL"
check "degrades gracefully without frontend-design" grep -qiE "fall back|fallback|degrade|not available|unavailable" "$SKILL"

# --- theme presets ------------------------------------------------------
check "dark-blue preset exists" test -f "$THEMES/dark-blue.yml"
check "dark-blue uses the Primer background" grep -q "0d1117" "$THEMES/dark-blue.yml"
check "dark-jade preset exists" test -f "$THEMES/dark-jade.yml"
check "light-jade preset exists" test -f "$THEMES/light-jade.yml"

# --- deck template ------------------------------------------------------
check "deck HTML template exists" test -f "$DECK_TMPL"
check "deck template is self-contained (no external assets / mermaid inline)" grep -qiE "mermaid|<style|<script" "$DECK_TMPL"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
