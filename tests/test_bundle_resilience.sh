#!/usr/bin/env bash
# tests/test_bundle_resilience.sh — setup must survive a stale .octopus.yml that
# references a renamed or removed bundle. A renamed bundle resolves via the alias
# map; a truly unknown one is warned-and-skipped, never aborting setup (set -e).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# setup.sh enables `set -euo pipefail`; relax it here (we assert via counters and
# deliberately exercise non-zero returns).
source "$SCRIPT_DIR/setup.sh" --source-only
set +e +u
OCTOPUS_DIR="$SCRIPT_DIR"

_contains() { local n="$1"; shift; local x; for x in "$@"; do [[ "$x" == "$n" ]] && return 0; done; return 1; }

# --- A: renamed bundle resolves via alias (knowledge-ops → knowledge) -------
OCTOPUS_SKILLS=(); OCTOPUS_ROLES=(); OCTOPUS_RULES=(); OCTOPUS_MCP=()
_load_bundle knowledge-ops; rc=$?
if [[ $rc -eq 0 ]] && _contains knowledge-hygiene "${OCTOPUS_SKILLS[@]}"; then
  ok "renamed bundle 'knowledge-ops' resolves to 'knowledge'"
else
  bad "renamed bundle 'knowledge-ops' resolves to 'knowledge' (rc=$rc)"
fi

# --- B: unknown bundle is skipped, non-fatal -------------------------------
OCTOPUS_SKILLS=(); OCTOPUS_ROLES=(); OCTOPUS_RULES=(); OCTOPUS_MCP=()
_load_bundle this-bundle-does-not-exist; rc=$?
if [[ $rc -eq 0 ]] && [[ ${#OCTOPUS_SKILLS[@]} -eq 0 ]]; then
  ok "unknown bundle is skipped (rc=0, nothing added)"
else
  bad "unknown bundle is skipped (rc=$rc, skills=${#OCTOPUS_SKILLS[@]})"
fi

# --- C: expand_bundles with a stale entry completes (would abort under set -e) -
( set -e
  source "$SCRIPT_DIR/setup.sh" --source-only
  OCTOPUS_DIR="$SCRIPT_DIR"
  OCTOPUS_SKILLS=(); OCTOPUS_ROLES=(); OCTOPUS_RULES=(); OCTOPUS_MCP=()
  OCTOPUS_BUNDLES=(starter knowledge-ops bogus-removed-bundle)
  expand_bundles
) >/dev/null 2>&1 \
  && ok "expand_bundles survives a stale bundle under set -e" \
  || bad "expand_bundles survives a stale bundle under set -e"

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
