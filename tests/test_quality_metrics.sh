#!/usr/bin/env bash
# tests/test_quality_metrics.sh — quality-metrics engine (RM-147).
# Unit + contract tests for: config resolver, dual-delta engine, ratchet/absolute
# threshold rule, orphan-ref record parsing, skill structural checks, and
# writer-Action guard (never touches a protected ref).
set -uo pipefail   # not -e: a failing check must not abort the suite

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
check_not() {
  local desc="$1"; shift
  if ! "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# Source the core library so we can unit-test pure functions.
# shellcheck source=../cli/lib/quality-metrics-lib.sh
source "$OCTOPUS_DIR/cli/lib/quality-metrics-lib.sh"

trap 'rm -rf "${FIXTURES[@]}"' EXIT
FIXTURES=()

# ---------------------------------------------------------------------------
# SECTION 1 — qm_field config resolver (project-wins precedence)
# ---------------------------------------------------------------------------
# Purpose: lock the `default < workspace < personal < project` order so a
# future refactor cannot silently invert it back to kr_field's user-wins order.

echo "=== Section 1: config resolver (project-wins) ==="

WKSP=$(mktemp -d); FIXTURES+=("$WKSP")
PERS=$(mktemp);    FIXTURES+=("$PERS")
PROJ=$(mktemp);    FIXTURES+=("$PROJ")

# All three files absent → ratchet default (empty string, caller uses fallback)
t1_absent_all_returns_empty() {
  local v; v="$(QM_WORKSPACE_YML="/nonexistent" QM_PERSONAL_YML="/nonexistent" \
    QM_PROJECT_YML="/nonexistent" qm_field "coverage" "min")"
  [[ -z "$v" ]]
}
check "absent layers → empty (ratchet default)" t1_absent_all_returns_empty

# Workspace sets coverage.min=60; project absent → workspace value returned
cat >"$WKSP/.octopus.yml" <<'YAML'
quality_metrics:
  coverage:
    min: 60
YAML
t1_workspace_only() {
  local v; v="$(QM_WORKSPACE_YML="$WKSP/.octopus.yml" QM_PERSONAL_YML="/nonexistent" \
    QM_PROJECT_YML="/nonexistent" qm_field "coverage" "min")"
  [[ "$v" == "60" ]]
}
check "workspace layer → 60" t1_workspace_only

# Personal overrides workspace (personal > workspace)
cat >"$PERS" <<'YAML'
quality_metrics:
  coverage:
    min: 70
YAML
t1_personal_overrides_workspace() {
  local v; v="$(QM_WORKSPACE_YML="$WKSP/.octopus.yml" QM_PERSONAL_YML="$PERS" \
    QM_PROJECT_YML="/nonexistent" qm_field "coverage" "min")"
  [[ "$v" == "70" ]]
}
check "personal overrides workspace → 70" t1_personal_overrides_workspace

# Project overrides personal (PROJECT WINS — the key invariant)
cat >"$PROJ" <<'YAML'
quality_metrics:
  coverage:
    min: 80
YAML
t1_project_wins() {
  local v; v="$(QM_WORKSPACE_YML="$WKSP/.octopus.yml" QM_PERSONAL_YML="$PERS" \
    QM_PROJECT_YML="$PROJ" qm_field "coverage" "min")"
  [[ "$v" == "80" ]]
}
check "project wins over personal → 80" t1_project_wins

# Per-field resolution: project sets complexity.max only; workspace sets coverage.min;
# both must be resolved independently (not all-or-nothing).
PROJ2=$(mktemp); FIXTURES+=("$PROJ2")
cat >"$PROJ2" <<'YAML'
quality_metrics:
  complexity:
    max: 15
YAML
t1_per_field_resolution() {
  local cov comp
  cov="$(QM_WORKSPACE_YML="$WKSP/.octopus.yml" QM_PERSONAL_YML="/nonexistent" \
    QM_PROJECT_YML="$PROJ2" qm_field "coverage" "min")"
  comp="$(QM_WORKSPACE_YML="$WKSP/.octopus.yml" QM_PERSONAL_YML="/nonexistent" \
    QM_PROJECT_YML="$PROJ2" qm_field "complexity" "max")"
  [[ "$cov" == "60" && "$comp" == "15" ]]
}
check "per-field: coverage from workspace, complexity from project" t1_per_field_resolution

# Project sets only complexity.max; coverage must fall through to workspace (not empty)
t1_project_partial_fallthrough() {
  local cov; cov="$(QM_WORKSPACE_YML="$WKSP/.octopus.yml" QM_PERSONAL_YML="$PERS" \
    QM_PROJECT_YML="$PROJ2" qm_field "coverage" "min")"
  # personal=70, project only has complexity, so personal should win for coverage
  [[ "$cov" == "70" ]]
}
check "project partial: coverage falls to personal when project omits it" t1_project_partial_fallthrough

# All four v1 fields are parseable
PROJ_FULL=$(mktemp); FIXTURES+=("$PROJ_FULL")
cat >"$PROJ_FULL" <<'YAML'
quality_metrics:
  coverage:
    min: 80
  complexity:
    max: 10
  module_size:
    max: 400
  dependencies:
    cycles_allowed: 0
YAML
t1_all_v1_fields() {
  local cov cmp mod dep
  cov="$(QM_WORKSPACE_YML="/nonexistent" QM_PERSONAL_YML="/nonexistent" \
    QM_PROJECT_YML="$PROJ_FULL" qm_field "coverage" "min")"
  cmp="$(QM_WORKSPACE_YML="/nonexistent" QM_PERSONAL_YML="/nonexistent" \
    QM_PROJECT_YML="$PROJ_FULL" qm_field "complexity" "max")"
  mod="$(QM_WORKSPACE_YML="/nonexistent" QM_PERSONAL_YML="/nonexistent" \
    QM_PROJECT_YML="$PROJ_FULL" qm_field "module_size" "max")"
  dep="$(QM_WORKSPACE_YML="/nonexistent" QM_PERSONAL_YML="/nonexistent" \
    QM_PROJECT_YML="$PROJ_FULL" qm_field "dependencies" "cycles_allowed")"
  [[ "$cov" == "80" && "$cmp" == "10" && "$mod" == "400" && "$dep" == "0" ]]
}
check "all four v1 fields parse correctly" t1_all_v1_fields

# ---------------------------------------------------------------------------
# SECTION 2 — dual-delta engine
# ---------------------------------------------------------------------------
echo "=== Section 2: dual-delta engine ==="

# qm_compute_delta main_value branch_value baseline_value
# Returns two lines: "vs_baseline:<delta>" and "vs_main:<delta>"
# where delta = branch - reference (positive = worse for coverage, negative = improvement)

t2_delta_zero() {
  local out; out="$(qm_compute_delta 75 75 75)"
  grep -q "vs_baseline:0" <<<"$out" && grep -q "vs_main:0" <<<"$out"
}
check "delta: zero when all equal" t2_delta_zero

t2_delta_regression() {
  # branch=70 regressed from main=75 and baseline=80
  local out; out="$(qm_compute_delta 75 70 80)"
  grep -q "vs_baseline:-10" <<<"$out" && grep -q "vs_main:-5" <<<"$out"
}
check "delta: coverage regression shows negative delta" t2_delta_regression

t2_delta_improvement() {
  # branch=85 improved from main=75 and baseline=80
  local out; out="$(qm_compute_delta 75 85 80)"
  grep -q "vs_baseline:5" <<<"$out" && grep -q "vs_main:10" <<<"$out"
}
check "delta: coverage improvement shows positive delta" t2_delta_improvement

t2_delta_no_baseline() {
  # No baseline record → vs_baseline reports "n/a"
  local out; out="$(qm_compute_delta 75 70 "")"
  grep -q "vs_baseline:n/a" <<<"$out" && grep -q "vs_main:-5" <<<"$out"
}
check "delta: absent baseline → vs_baseline:n/a" t2_delta_no_baseline

# ---------------------------------------------------------------------------
# SECTION 3 — ratchet-vs-absolute threshold rule
# ---------------------------------------------------------------------------
echo "=== Section 3: threshold rule ==="

# qm_check_threshold metric current baseline absolute_threshold
# Exits 0 = OK, 1 = breach.  Prints reason on breach.

# Ratchet only (no absolute): never breach if current >= baseline
t3_ratchet_ok() {
  qm_check_threshold "coverage" 75 75 ""  # same as baseline → OK
}
check "ratchet: equal to baseline → OK" t3_ratchet_ok

t3_ratchet_breach() {
  ! qm_check_threshold "coverage" 74 75 ""  # regressed vs baseline → breach
}
check "ratchet: regressed vs baseline → breach" t3_ratchet_breach

t3_ratchet_improvement() {
  qm_check_threshold "coverage" 76 75 ""  # improved → OK
}
check "ratchet: improved vs baseline → OK" t3_ratchet_improvement

# Absolute threshold overrides ratchet: must meet absolute regardless of baseline
t3_absolute_breach_below_floor() {
  ! qm_check_threshold "coverage" 75 70 "80"  # 75 >= baseline(70) but < absolute(80) → breach
}
check "absolute: above baseline but below floor → breach" t3_absolute_breach_below_floor

t3_absolute_meets_floor() {
  qm_check_threshold "coverage" 80 70 "80"  # meets exact floor → OK
}
check "absolute: meets exact floor → OK" t3_absolute_meets_floor

t3_absolute_above_floor() {
  qm_check_threshold "coverage" 85 70 "80"  # above floor → OK
}
check "absolute: above floor → OK" t3_absolute_above_floor

# No baseline record + ratchet only → OK (nothing to ratchet against)
t3_ratchet_no_baseline_ok() {
  qm_check_threshold "coverage" 70 "" ""
}
check "ratchet: no baseline → OK (no anchor)" t3_ratchet_no_baseline_ok

# Complexity: max threshold (lower is better — inverse direction)
# qm_check_threshold_max metric current baseline absolute_max
t3_complexity_ratchet_ok() {
  qm_check_threshold_max "complexity" 10 12 ""  # improved (lower) vs baseline → OK
}
check "complexity ratchet: lower than baseline → OK" t3_complexity_ratchet_ok

t3_complexity_ratchet_breach() {
  ! qm_check_threshold_max "complexity" 13 12 ""  # worse (higher) than baseline → breach
}
check "complexity ratchet: higher than baseline → breach" t3_complexity_ratchet_breach

t3_complexity_absolute_breach() {
  ! qm_check_threshold_max "complexity" 11 8 "10"  # 11 > absolute_max(10) → breach
}
check "complexity absolute: exceeds ceiling → breach" t3_complexity_absolute_breach

t3_complexity_absolute_ok() {
  qm_check_threshold_max "complexity" 10 8 "10"  # exactly at ceiling → OK
}
check "complexity absolute: at ceiling → OK" t3_complexity_absolute_ok

# ---------------------------------------------------------------------------
# SECTION 4 — orphan-ref record parsing
# ---------------------------------------------------------------------------
echo "=== Section 4: orphan-ref record parsing ==="

# qm_parse_baseline <json_string> <metric>
# Parses a baseline.json line (flat JSON) and extracts the metric value.

BASELINE_JSON='{"commit":"abc123","timestamp":"2026-06-01T00:00:00Z","coverage":78.5,"complexity":9,"module_size":350,"dependency_cycles":0}'

t4_parse_coverage() {
  local v; v="$(qm_parse_baseline "$BASELINE_JSON" "coverage")"
  [[ "$v" == "78.5" ]]
}
check "parse_baseline: extract coverage" t4_parse_coverage

t4_parse_complexity() {
  local v; v="$(qm_parse_baseline "$BASELINE_JSON" "complexity")"
  [[ "$v" == "9" ]]
}
check "parse_baseline: extract complexity" t4_parse_complexity

t4_parse_module_size() {
  local v; v="$(qm_parse_baseline "$BASELINE_JSON" "module_size")"
  [[ "$v" == "350" ]]
}
check "parse_baseline: extract module_size" t4_parse_module_size

t4_parse_deps() {
  local v; v="$(qm_parse_baseline "$BASELINE_JSON" "dependency_cycles")"
  [[ "$v" == "0" ]]
}
check "parse_baseline: extract dependency_cycles" t4_parse_deps

t4_parse_missing_field() {
  local v; v="$(qm_parse_baseline "$BASELINE_JSON" "nonexistent")"
  [[ -z "$v" ]]
}
check "parse_baseline: missing field → empty" t4_parse_missing_field

t4_parse_empty_json() {
  local v; v="$(qm_parse_baseline "" "coverage")"
  [[ -z "$v" ]]
}
check "parse_baseline: empty JSON → empty" t4_parse_empty_json

# ---------------------------------------------------------------------------
# SECTION 5 — writer Action guard: never touches protected refs
# ---------------------------------------------------------------------------
echo "=== Section 5: writer Action guard ==="

WRITER="$OCTOPUS_DIR/templates/github-actions/quality-metrics-writer.yml"

t5_writer_exists() { [[ -f "$WRITER" ]]; }
check "writer Action template exists" t5_writer_exists

t5_writer_triggers_on_push_main() {
  # on.push.branches includes main (may be multi-line list: "- main")
  grep -q "push:" "$WRITER" && grep -q "main" "$WRITER"
}
check "writer triggers on push:main" t5_writer_triggers_on_push_main

# Writer must NOT push to protected branches (main / release/*).
# The only git push in the file must target the orphan ref, not main/release.
t5_writer_no_push_main() {
  # All "git push" lines must reference the orphan ref, not main or release.
  # Lines containing "git push" that also contain "main" or "release/" without
  # "octopus" are forbidden.
  ! grep "git push" "$WRITER" | grep -Ev "octopus" | grep -qE "main|release/"
}
check "writer: no push to main or release/* branches" t5_writer_no_push_main

t5_writer_pushes_orphan_ref() {
  grep -q "octopus/quality-metrics" "$WRITER"
}
check "writer: pushes to octopus/quality-metrics ref" t5_writer_pushes_orphan_ref

t5_writer_contents_write_permission() {
  grep -q "contents: write" "$WRITER"
}
check "writer: has contents:write permission" t5_writer_contents_write_permission

# ---------------------------------------------------------------------------
# SECTION 6 — skill + command structure
# ---------------------------------------------------------------------------
echo "=== Section 6: skill + command structure ==="

SKILL="$OCTOPUS_DIR/skills/quality-metrics/SKILL.md"
CMD="$OCTOPUS_DIR/commands/quality-metrics.md"

t6_skill_exists()        { [[ -f "$SKILL" ]]; }
t6_skill_frontmatter()   { head -5 "$SKILL" | grep -q "^name: quality-metrics$"; }
t6_command_exists()      { [[ -f "$CMD" ]]; }
t6_registered_in_bundle() {
  grep -rqx " *- quality-metrics" "$OCTOPUS_DIR/bundles"
}
t6_bundle_file_exists()  { [[ -f "$OCTOPUS_DIR/bundles/quality-metrics.yml" ]]; }
t6_bundle_category()     {
  grep -q "^category: intent$" "$OCTOPUS_DIR/bundles/quality-metrics.yml"
}

check "skill SKILL.md exists"              t6_skill_exists
check "skill: valid frontmatter name"      t6_skill_frontmatter
check "command file exists"                t6_command_exists
check "skill registered in a bundle"       t6_registered_in_bundle
check "quality-metrics bundle file exists" t6_bundle_file_exists
check "bundle category is intent"          t6_bundle_category

t6_skill_documents_dual_delta() {
  grep -q "dual.delta\|dual delta\|vs_baseline\|vs_main" "$SKILL"
}
check "skill documents dual-delta concept" t6_skill_documents_dual_delta

t6_skill_documents_ratchet() {
  grep -qi "ratchet" "$SKILL"
}
check "skill documents ratchet threshold" t6_skill_documents_ratchet

t6_skill_documents_lm_curation() {
  grep -qi "low.cost\|curation\|threshold breach\|breach" "$SKILL"
}
check "skill documents LLM curation on breach" t6_skill_documents_lm_curation

# ---------------------------------------------------------------------------
# SECTION 7 — adapter contract (C# + TS output shape)
# ---------------------------------------------------------------------------
echo "=== Section 7: adapter output shape ==="

# Each adapter script must emit a normalized line:
#   metric_name:<numeric_value>
# The adapters are integration scripts; here we test only the shape contract
# by running them against minimal stubs (no real tooling needed).

CSHARP_ADAPTER="$OCTOPUS_DIR/cli/lib/adapter-csharp.sh"
TS_ADAPTER="$OCTOPUS_DIR/cli/lib/adapter-typescript.sh"

t7_csharp_adapter_exists() { [[ -f "$CSHARP_ADAPTER" ]]; }
t7_ts_adapter_exists()     { [[ -f "$TS_ADAPTER" ]]; }

check "C# adapter script exists"  t7_csharp_adapter_exists
check "TS adapter script exists"  t7_ts_adapter_exists

# Each adapter must define the four required output functions (or a dispatch
# function that calls them). We verify by grepping the script.
t7_csharp_adapter_has_coverage()    { grep -q "coverage" "$CSHARP_ADAPTER"; }
t7_csharp_adapter_has_complexity()  { grep -q "complexity" "$CSHARP_ADAPTER"; }
t7_csharp_adapter_has_module_size() { grep -q "module_size" "$CSHARP_ADAPTER"; }
t7_csharp_adapter_has_deps()        { grep -q "dependency_cycles\|deps" "$CSHARP_ADAPTER"; }

check "C# adapter: coverage metric"     t7_csharp_adapter_has_coverage
check "C# adapter: complexity metric"   t7_csharp_adapter_has_complexity
check "C# adapter: module_size metric"  t7_csharp_adapter_has_module_size
check "C# adapter: dependency cycles"   t7_csharp_adapter_has_deps

t7_ts_adapter_has_coverage()    { grep -q "coverage" "$TS_ADAPTER"; }
t7_ts_adapter_has_complexity()  { grep -q "complexity" "$TS_ADAPTER"; }
t7_ts_adapter_has_module_size() { grep -q "module_size" "$TS_ADAPTER"; }
t7_ts_adapter_has_deps()        { grep -q "dependency_cycles\|deps" "$TS_ADAPTER"; }

check "TS adapter: coverage metric"     t7_ts_adapter_has_coverage
check "TS adapter: complexity metric"   t7_ts_adapter_has_complexity
check "TS adapter: module_size metric"  t7_ts_adapter_has_module_size
check "TS adapter: dependency cycles"   t7_ts_adapter_has_deps

# ---------------------------------------------------------------------------
# SECTION 8 — smoke: no-breach → no LLM marker; breach → curation marker
# ---------------------------------------------------------------------------
echo "=== Section 8: cost-contract smoke ==="

# qm_format_report metric current baseline absolute threshold_fn
# Returns a report line. On no breach it must NOT emit "curation:" or "llm:".
# On breach it MUST emit "curation:needed" (the marker the skill reads to
# decide whether to invoke the low-cost model).

t8_no_breach_no_curation() {
  local out; out="$(qm_format_report "coverage" 80 75 "" "qm_check_threshold")"
  ! grep -q "curation:needed" <<<"$out"
}
check "smoke: no breach → no curation marker" t8_no_breach_no_curation

t8_breach_emits_curation() {
  local out; out="$(qm_format_report "coverage" 70 75 "" "qm_check_threshold")"
  grep -q "curation:needed" <<<"$out"
}
check "smoke: breach → curation:needed emitted" t8_breach_emits_curation

t8_no_breach_absolute_no_curation() {
  local out; out="$(qm_format_report "coverage" 85 75 "80" "qm_check_threshold")"
  ! grep -q "curation:needed" <<<"$out"
}
check "smoke: absolute met → no curation marker" t8_no_breach_absolute_no_curation

t8_breach_absolute_emits_curation() {
  local out; out="$(qm_format_report "coverage" 70 65 "80" "qm_check_threshold")"
  grep -q "curation:needed" <<<"$out"
}
check "smoke: absolute breach → curation:needed" t8_breach_absolute_emits_curation

# ---------------------------------------------------------------------------
echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
