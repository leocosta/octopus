#!/usr/bin/env bash
# tests/test_team_continuous_learning.sh
# Structural tests for the team mode of continuous-learning (RM-093).
# Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/continuous-learning/SKILL.md"
HOOK="$OCTOPUS_DIR/hooks/stop/review-log-capture.sh"
HOOKS_JSON="$OCTOPUS_DIR/hooks/hooks.json"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- team mode on continuous-learning -----------------------------------
check "continuous-learning has a Team mode section" grep -qiE "^#+ .*team mode|## Team mode" "$SKILL"
check "team mode aggregates review feedback" grep -qiE "review.*feedback|pr-review|architect|mentor" "$SKILL"
check "team mode reads the review-log" grep -q ".octopus/review-log" "$SKILL"
check "team mode resolves the fleet (fleet.yml)" grep -q "fleet.yml" "$SKILL"
check "uses occurrence + repo-spread thresholds" grep -qiE "spread|distinct.?repo|across.*repos|fleet_repos" "$SKILL"
check "thresholds configurable with defaults" grep -qiE "learning:|local: 5|fleet_repos|default" "$SKILL"
check "fleet-wide pattern routes to the workspace rules" grep -qiE "workspace.*rule|workspace:|shared rule" "$SKILL"
check "single-repo pattern routes local" grep -qiE "single-repo|local candidate|local rule" "$SKILL"
check "writes candidates to .octopus/proposals" grep -q ".octopus/proposals" "$SKILL"
check "promotes via review-proposals" grep -qi "review-proposals" "$SKILL"
check "human-gated, no auto-promote" grep -qiE "no auto|never auto|human-gated|human gate|no auto-promote|not auto" "$SKILL"

# --- the capture Stop hook ----------------------------------------------
check "review-log-capture hook exists" test -f "$HOOK"
check "hook reads the session transcript" grep -qi "transcript_path" "$HOOK"
check "hook detects review findings (severity tags)" grep -qE "BLOCKING|ADVISORY|QUESTION" "$HOOK"
check "hook appends to .octopus/review-log" grep -q ".octopus/review-log" "$HOOK"
check "hook soft-skips without jq/transcript" grep -qiE "exit 0" "$HOOK"
check "hook registered in hooks.json (Stop)" grep -q "review-log-capture" "$HOOKS_JSON"

# --- gitignore for the review-log ---------------------------------------
check ".octopus/review-log/ is gitignored" grep -q ".octopus/review-log" "$OCTOPUS_DIR/.gitignore"

# --- bundle (continuous-learning already shipped in docs) ----------------
check "continuous-learning registered in docs bundle" grep -q "continuous-learning" "$OCTOPUS_DIR/bundles/docs.yml"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
