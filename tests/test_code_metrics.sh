#!/usr/bin/env bash
# tests/test_code_metrics.sh — code-metrics engine (RM-147).
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
# shellcheck source=../cli/lib/code-metrics-lib.sh
source "$OCTOPUS_DIR/cli/lib/code-metrics-lib.sh"

trap 'rm -rf "${FIXTURES[@]}"' EXIT
FIXTURES=()

# ---------------------------------------------------------------------------
# SECTION 1 — cm_field config resolver (project-wins precedence)
# ---------------------------------------------------------------------------
# Purpose: lock the `default < workspace < personal < project` order so a
# future refactor cannot silently invert it back to kr_field's user-wins order.

echo "=== Section 1: config resolver (project-wins) ==="

WKSP=$(mktemp -d); FIXTURES+=("$WKSP")
PERS=$(mktemp);    FIXTURES+=("$PERS")
PROJ=$(mktemp);    FIXTURES+=("$PROJ")

# All three files absent → ratchet default (empty string, caller uses fallback)
t1_absent_all_returns_empty() {
  local v; v="$(CM_WORKSPACE_YML="/nonexistent" CM_PERSONAL_YML="/nonexistent" \
    CM_PROJECT_YML="/nonexistent" cm_field "coverage" "min")"
  [[ -z "$v" ]]
}
check "absent layers → empty (ratchet default)" t1_absent_all_returns_empty

# Workspace sets coverage.min=60; project absent → workspace value returned
cat >"$WKSP/.octopus.yml" <<'YAML'
code_metrics:
  coverage:
    min: 60
YAML
t1_workspace_only() {
  local v; v="$(CM_WORKSPACE_YML="$WKSP/.octopus.yml" CM_PERSONAL_YML="/nonexistent" \
    CM_PROJECT_YML="/nonexistent" cm_field "coverage" "min")"
  [[ "$v" == "60" ]]
}
check "workspace layer → 60" t1_workspace_only

# Personal overrides workspace (personal > workspace)
cat >"$PERS" <<'YAML'
code_metrics:
  coverage:
    min: 70
YAML
t1_personal_overrides_workspace() {
  local v; v="$(CM_WORKSPACE_YML="$WKSP/.octopus.yml" CM_PERSONAL_YML="$PERS" \
    CM_PROJECT_YML="/nonexistent" cm_field "coverage" "min")"
  [[ "$v" == "70" ]]
}
check "personal overrides workspace → 70" t1_personal_overrides_workspace

# Project overrides personal (PROJECT WINS — the key invariant)
cat >"$PROJ" <<'YAML'
code_metrics:
  coverage:
    min: 80
YAML
t1_project_wins() {
  local v; v="$(CM_WORKSPACE_YML="$WKSP/.octopus.yml" CM_PERSONAL_YML="$PERS" \
    CM_PROJECT_YML="$PROJ" cm_field "coverage" "min")"
  [[ "$v" == "80" ]]
}
check "project wins over personal → 80" t1_project_wins

# Per-field resolution: project sets complexity.max only; workspace sets coverage.min;
# both must be resolved independently (not all-or-nothing).
PROJ2=$(mktemp); FIXTURES+=("$PROJ2")
cat >"$PROJ2" <<'YAML'
code_metrics:
  complexity:
    max: 15
YAML
t1_per_field_resolution() {
  local cov comp
  cov="$(CM_WORKSPACE_YML="$WKSP/.octopus.yml" CM_PERSONAL_YML="/nonexistent" \
    CM_PROJECT_YML="$PROJ2" cm_field "coverage" "min")"
  comp="$(CM_WORKSPACE_YML="$WKSP/.octopus.yml" CM_PERSONAL_YML="/nonexistent" \
    CM_PROJECT_YML="$PROJ2" cm_field "complexity" "max")"
  [[ "$cov" == "60" && "$comp" == "15" ]]
}
check "per-field: coverage from workspace, complexity from project" t1_per_field_resolution

# Project sets only complexity.max; coverage must fall through to workspace (not empty)
t1_project_partial_fallthrough() {
  local cov; cov="$(CM_WORKSPACE_YML="$WKSP/.octopus.yml" CM_PERSONAL_YML="$PERS" \
    CM_PROJECT_YML="$PROJ2" cm_field "coverage" "min")"
  # personal=70, project only has complexity, so personal should win for coverage
  [[ "$cov" == "70" ]]
}
check "project partial: coverage falls to personal when project omits it" t1_project_partial_fallthrough

# All four v1 fields are parseable
PROJ_FULL=$(mktemp); FIXTURES+=("$PROJ_FULL")
cat >"$PROJ_FULL" <<'YAML'
code_metrics:
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
  cov="$(CM_WORKSPACE_YML="/nonexistent" CM_PERSONAL_YML="/nonexistent" \
    CM_PROJECT_YML="$PROJ_FULL" cm_field "coverage" "min")"
  cmp="$(CM_WORKSPACE_YML="/nonexistent" CM_PERSONAL_YML="/nonexistent" \
    CM_PROJECT_YML="$PROJ_FULL" cm_field "complexity" "max")"
  mod="$(CM_WORKSPACE_YML="/nonexistent" CM_PERSONAL_YML="/nonexistent" \
    CM_PROJECT_YML="$PROJ_FULL" cm_field "module_size" "max")"
  dep="$(CM_WORKSPACE_YML="/nonexistent" CM_PERSONAL_YML="/nonexistent" \
    CM_PROJECT_YML="$PROJ_FULL" cm_field "dependencies" "cycles_allowed")"
  [[ "$cov" == "80" && "$cmp" == "10" && "$mod" == "400" && "$dep" == "0" ]]
}
check "all four v1 fields parse correctly" t1_all_v1_fields

# ---------------------------------------------------------------------------
# SECTION 2 — dual-delta engine
# ---------------------------------------------------------------------------
echo "=== Section 2: dual-delta engine ==="

# cm_compute_delta main_value branch_value baseline_value
# Returns two lines: "vs_baseline:<delta>" and "vs_main:<delta>"
# where delta = branch - reference (positive = worse for coverage, negative = improvement)

t2_delta_zero() {
  local out; out="$(cm_compute_delta 75 75 75)"
  grep -q "vs_baseline:0" <<<"$out" && grep -q "vs_main:0" <<<"$out"
}
check "delta: zero when all equal" t2_delta_zero

t2_delta_regression() {
  # branch=70 regressed from main=75 and baseline=80
  local out; out="$(cm_compute_delta 75 70 80)"
  grep -q "vs_baseline:-10" <<<"$out" && grep -q "vs_main:-5" <<<"$out"
}
check "delta: coverage regression shows negative delta" t2_delta_regression

t2_delta_improvement() {
  # branch=85 improved from main=75 and baseline=80
  local out; out="$(cm_compute_delta 75 85 80)"
  grep -q "vs_baseline:5" <<<"$out" && grep -q "vs_main:10" <<<"$out"
}
check "delta: coverage improvement shows positive delta" t2_delta_improvement

t2_delta_no_baseline() {
  # No baseline record → vs_baseline reports "n/a"
  local out; out="$(cm_compute_delta 75 70 "")"
  grep -q "vs_baseline:n/a" <<<"$out" && grep -q "vs_main:-5" <<<"$out"
}
check "delta: absent baseline → vs_baseline:n/a" t2_delta_no_baseline

# ---------------------------------------------------------------------------
# SECTION 3 — ratchet-vs-absolute threshold rule
# ---------------------------------------------------------------------------
echo "=== Section 3: threshold rule ==="

# cm_check_threshold metric current baseline absolute_threshold
# Exits 0 = OK, 1 = breach.  Prints reason on breach.

# Ratchet only (no absolute): never breach if current >= baseline
t3_ratchet_ok() {
  cm_check_threshold "coverage" 75 75 ""  # same as baseline → OK
}
check "ratchet: equal to baseline → OK" t3_ratchet_ok

t3_ratchet_breach() {
  ! cm_check_threshold "coverage" 74 75 ""  # regressed vs baseline → breach
}
check "ratchet: regressed vs baseline → breach" t3_ratchet_breach

t3_ratchet_improvement() {
  cm_check_threshold "coverage" 76 75 ""  # improved → OK
}
check "ratchet: improved vs baseline → OK" t3_ratchet_improvement

# Absolute threshold overrides ratchet: must meet absolute regardless of baseline
t3_absolute_breach_below_floor() {
  ! cm_check_threshold "coverage" 75 70 "80"  # 75 >= baseline(70) but < absolute(80) → breach
}
check "absolute: above baseline but below floor → breach" t3_absolute_breach_below_floor

t3_absolute_meets_floor() {
  cm_check_threshold "coverage" 80 70 "80"  # meets exact floor → OK
}
check "absolute: meets exact floor → OK" t3_absolute_meets_floor

t3_absolute_above_floor() {
  cm_check_threshold "coverage" 85 70 "80"  # above floor → OK
}
check "absolute: above floor → OK" t3_absolute_above_floor

# No baseline record + ratchet only → OK (nothing to ratchet against)
t3_ratchet_no_baseline_ok() {
  cm_check_threshold "coverage" 70 "" ""
}
check "ratchet: no baseline → OK (no anchor)" t3_ratchet_no_baseline_ok

# Complexity: max threshold (lower is better — inverse direction)
# cm_check_threshold_max metric current baseline absolute_max
t3_complexity_ratchet_ok() {
  cm_check_threshold_max "complexity" 10 12 ""  # improved (lower) vs baseline → OK
}
check "complexity ratchet: lower than baseline → OK" t3_complexity_ratchet_ok

t3_complexity_ratchet_breach() {
  ! cm_check_threshold_max "complexity" 13 12 ""  # worse (higher) than baseline → breach
}
check "complexity ratchet: higher than baseline → breach" t3_complexity_ratchet_breach

t3_complexity_absolute_breach() {
  ! cm_check_threshold_max "complexity" 11 8 "10"  # 11 > absolute_max(10) → breach
}
check "complexity absolute: exceeds ceiling → breach" t3_complexity_absolute_breach

t3_complexity_absolute_ok() {
  cm_check_threshold_max "complexity" 10 8 "10"  # exactly at ceiling → OK
}
check "complexity absolute: at ceiling → OK" t3_complexity_absolute_ok

# ---------------------------------------------------------------------------
# SECTION 4 — orphan-ref record parsing
# ---------------------------------------------------------------------------
echo "=== Section 4: orphan-ref record parsing ==="

# cm_parse_baseline <json_string> <metric>
# Parses a baseline.json line (flat JSON) and extracts the metric value.

BASELINE_JSON='{"commit":"abc123","timestamp":"2026-06-01T00:00:00Z","coverage":78.5,"complexity":9,"module_size":350,"dependency_cycles":0}'

t4_parse_coverage() {
  local v; v="$(cm_parse_baseline "$BASELINE_JSON" "coverage")"
  [[ "$v" == "78.5" ]]
}
check "parse_baseline: extract coverage" t4_parse_coverage

t4_parse_complexity() {
  local v; v="$(cm_parse_baseline "$BASELINE_JSON" "complexity")"
  [[ "$v" == "9" ]]
}
check "parse_baseline: extract complexity" t4_parse_complexity

t4_parse_module_size() {
  local v; v="$(cm_parse_baseline "$BASELINE_JSON" "module_size")"
  [[ "$v" == "350" ]]
}
check "parse_baseline: extract module_size" t4_parse_module_size

t4_parse_deps() {
  local v; v="$(cm_parse_baseline "$BASELINE_JSON" "dependency_cycles")"
  [[ "$v" == "0" ]]
}
check "parse_baseline: extract dependency_cycles" t4_parse_deps

t4_parse_missing_field() {
  local v; v="$(cm_parse_baseline "$BASELINE_JSON" "nonexistent")"
  [[ -z "$v" ]]
}
check "parse_baseline: missing field → empty" t4_parse_missing_field

t4_parse_empty_json() {
  local v; v="$(cm_parse_baseline "" "coverage")"
  [[ -z "$v" ]]
}
check "parse_baseline: empty JSON → empty" t4_parse_empty_json

# ---------------------------------------------------------------------------
# SECTION 5 — writer Action guard: never touches protected refs
# ---------------------------------------------------------------------------
echo "=== Section 5: writer Action guard ==="

WRITER="$OCTOPUS_DIR/templates/github-actions/code-metrics-writer.yml"

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
  grep -q "octopus/code-metrics" "$WRITER"
}
check "writer: pushes to octopus/code-metrics ref" t5_writer_pushes_orphan_ref

t5_writer_contents_write_permission() {
  grep -q "contents: write" "$WRITER"
}
check "writer: has contents:write permission" t5_writer_contents_write_permission

# ---------------------------------------------------------------------------
# SECTION 6 — skill + command structure
# ---------------------------------------------------------------------------
echo "=== Section 6: skill + command structure ==="

SKILL="$OCTOPUS_DIR/skills/code-metrics/SKILL.md"
CMD="$OCTOPUS_DIR/commands/code-metrics.md"

t6_skill_exists()        { [[ -f "$SKILL" ]]; }
t6_skill_frontmatter()   { head -5 "$SKILL" | grep -q "^name: code-metrics$"; }
t6_command_exists()      { [[ -f "$CMD" ]]; }
t6_registered_in_bundle() {
  # code-metrics is now a member of the quality bundle (no standalone bundle file)
  grep -rqx " *- code-metrics" "$OCTOPUS_DIR/bundles"
}
t6_registered_in_quality() {
  grep -qx "  - code-metrics" "$OCTOPUS_DIR/bundles/quality.yml"
}

check "skill SKILL.md exists"              t6_skill_exists
check "skill: valid frontmatter name"      t6_skill_frontmatter
check "command file exists"                t6_command_exists
check "skill registered in a bundle"       t6_registered_in_bundle
check "code-metrics is a member of quality bundle" t6_registered_in_quality

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

# cm_format_report metric current baseline absolute threshold_fn
# Returns a report line. On no breach it must NOT emit "curation:" or "llm:".
# On breach it MUST emit "curation:needed" (the marker the skill reads to
# decide whether to invoke the low-cost model).

t8_no_breach_no_curation() {
  local out; out="$(cm_format_report "coverage" 80 75 "" "cm_check_threshold")"
  ! grep -q "curation:needed" <<<"$out"
}
check "smoke: no breach → no curation marker" t8_no_breach_no_curation

t8_breach_emits_curation() {
  local out; out="$(cm_format_report "coverage" 70 75 "" "cm_check_threshold")"
  grep -q "curation:needed" <<<"$out"
}
check "smoke: breach → curation:needed emitted" t8_breach_emits_curation

t8_no_breach_absolute_no_curation() {
  local out; out="$(cm_format_report "coverage" 85 75 "80" "cm_check_threshold")"
  ! grep -q "curation:needed" <<<"$out"
}
check "smoke: absolute met → no curation marker" t8_no_breach_absolute_no_curation

t8_breach_absolute_emits_curation() {
  local out; out="$(cm_format_report "coverage" 70 65 "80" "cm_check_threshold")"
  grep -q "curation:needed" <<<"$out"
}
check "smoke: absolute breach → curation:needed" t8_breach_absolute_emits_curation

# ---------------------------------------------------------------------------
# SECTION 9 — awk code-injection guard (config + baseline are untrusted)
# ---------------------------------------------------------------------------
# Purpose: a malicious .octopus.yml layer or tampered orphan ref must never
# reach awk as program text. Values are validated numeric at the cm_field
# boundary and passed to awk via -v bindings (data, not code).
echo "=== Section 9: awk code-injection guard ==="

# A config value crafted to break out of an interpolated awk program and run a
# command. With the fix it is rejected as non-numeric (and could never execute
# even if it slipped through, because awk receives it via -v).
CM_EVIL=$(mktemp); FIXTURES+=("$CM_EVIL")
SENTINEL="$(mktemp -u)"; FIXTURES+=("$SENTINEL")
printf 'code_metrics:\n  coverage:\n    min: 0); system("touch %s"); print(0\n' "$SENTINEL" > "$CM_EVIL"

t9_malicious_config_rejected() {
  # cm_field must fail (non-zero) for a non-numeric value.
  ! CM_PROJECT_YML="$CM_EVIL" cm_field "coverage" "min" 2>/dev/null
}
check "injection: malicious config value rejected by cm_field" t9_malicious_config_rejected

t9_no_command_executed() {
  # The injected system("touch …") must NOT have run.
  CM_PROJECT_YML="$CM_EVIL" cm_field "coverage" "min" &>/dev/null || true
  [[ ! -e "$SENTINEL" ]]
}
check "injection: no command executed via config" t9_no_command_executed

t9_numeric_validator() {
  cm_is_numeric "80" && cm_is_numeric "-3.5" && ! cm_is_numeric '0); system("x")'
}
check "injection: cm_is_numeric accepts numbers, rejects code" t9_numeric_validator

t9_threshold_safe_with_injection() {
  # Even passed directly (bypassing cm_field), an arithmetic fn must not execute
  # injected code — -v bindings treat the value as data, coerced to 0.
  cm_check_threshold "coverage" '0); system("touch '"$SENTINEL"'") #' "" "80" &>/dev/null || true
  [[ ! -e "$SENTINEL" ]]
}
check "injection: cm_check_threshold passes value as awk data, not code" t9_threshold_safe_with_injection

t9_safe_filter_validator() {
  # Accepts real dotnet test --filter expressions; rejects quote-breaking and
  # shell/command metacharacters that could inject extra args.
  cm_is_safe_filter "Category!=Integration" \
    && cm_is_safe_filter "Category=A&Category=B|Name~Foo" \
    && ! cm_is_safe_filter 'X" --results-directory /tmp' \
    && ! cm_is_safe_filter 'X; touch /tmp/pwned' \
    && ! cm_is_safe_filter 'X$(touch /tmp/pwned)'
}
check "injection: cm_is_safe_filter accepts filters, rejects arg/command injection" t9_safe_filter_validator

# ---------------------------------------------------------------------------
# SECTION 10 — metric registry (cm_metric_spec)  [RM-148]
# ---------------------------------------------------------------------------
# Purpose: cm_metric_spec is the single source of truth mapping each metric to
# its `direction|config_block|config_field`. The dispatch loop in
# code-metrics.sh reads it instead of a hardcoded case, so adding a metric is a
# one-line registry entry. Direction ∈ {higher, lower, info}.
echo "=== Section 10: metric registry (cm_metric_spec) ==="

t10_existing_unchanged() {
  [[ "$(cm_metric_spec coverage)"          == "higher|coverage|min" ]] &&
  [[ "$(cm_metric_spec complexity)"        == "lower|complexity|max" ]] &&
  [[ "$(cm_metric_spec module_size)"       == "lower|module_size|max" ]] &&
  [[ "$(cm_metric_spec dependency_cycles)" == "lower|dependencies|cycles_allowed" ]]
}
check "registry: 4 existing metrics map to unchanged direction/field" t10_existing_unchanged

t10_rm148_counters() {
  [[ "$(cm_metric_spec todo_markers)"  == "lower|todo_markers|max" ]] &&
  [[ "$(cm_metric_spec deprecations)"  == "lower|deprecations|max" ]] &&
  [[ "$(cm_metric_spec dead_code)"     == "lower|dead_code|max" ]] &&
  [[ "$(cm_metric_spec suppressions)"  == "lower|suppressions|max" ]] &&
  [[ "$(cm_metric_spec nesting_depth)" == "lower|nesting_depth|max" ]] &&
  [[ "$(cm_metric_spec param_count)"   == "lower|param_count|max" ]] &&
  [[ "$(cm_metric_spec magic_numbers)" == "lower|magic_numbers|max" ]] &&
  [[ "$(cm_metric_spec lint_density)"  == "lower|lint_density|max" ]] &&
  [[ "$(cm_metric_spec doc_coverage)"  == "higher|doc_coverage|min" ]]
}
check "registry: RM-148 counters mapped (doc_coverage higher, rest lower)" t10_rm148_counters

t10_rm149_hotspots() {
  [[ "$(cm_metric_spec hotspots)" == "lower|hotspots|max" ]]
}
check "registry: RM-149 hotspots → lower|hotspots|max" t10_rm149_hotspots

t10_rm150_perf_info_only() {
  # perf_risk is info-only: no config field, must resolve to the info direction
  # so the dispatch loop skips the threshold check entirely.
  [[ "$(cm_metric_spec perf_risk)" == "info|perf_risk|" ]]
}
check "registry: RM-150 perf_risk → info direction, no threshold field" t10_rm150_perf_info_only

t10_unknown_empty() {
  [[ -z "$(cm_metric_spec definitely_not_a_metric)" ]]
}
check "registry: unknown metric → empty (no phantom dispatch)" t10_unknown_empty

t10_info_never_gates() {
  # An info-only metric routed through cm_format_report with cm_check_noop must
  # print its delta line and NEVER emit curation:needed, even on a "regression".
  local out; out="$(cm_format_report "perf_risk" 9 3 "" "cm_check_noop")"
  grep -q "metric:perf_risk current:9" <<<"$out" && ! grep -q "curation:needed" <<<"$out"
}
check "registry: cm_check_noop reports info metric without ever gating" t10_info_never_gates

# ---------------------------------------------------------------------------
# SECTION 11 — RM-148 counter helpers (pure, fixture-tested)
# ---------------------------------------------------------------------------
# Purpose: the v2 pack metrics are deterministic shell heuristics. Their cores
# are pure helpers tested here against inline fixtures; the adapters only feed
# them language-specific file lists / grep patterns.
echo "=== Section 11: RM-148 counter helpers ==="

CM_SRC=$(mktemp -d); FIXTURES+=("$CM_SRC")
mkdir -p "$CM_SRC/node_modules" "$CM_SRC/src"
printf '// TODO: fix\nint x=2; // FIXME later\nok\n' > "$CM_SRC/src/a.ts"
printf 'TODO everywhere\n' > "$CM_SRC/node_modules/vendor.ts"   # must be pruned

t11_count_matches() {
  # 2 matching lines under src/, node_modules pruned.
  [[ "$(cm_count_matches 'TODO|FIXME' "$CM_SRC")" == "2" ]]
}
check "counter: cm_count_matches counts matches, prunes vendor dirs" t11_count_matches

t11_count_matches_absent_path() {
  [[ "$(cm_count_matches 'TODO' /nonexistent/path)" == "0" ]]
}
check "counter: cm_count_matches → 0 for absent path" t11_count_matches_absent_path

t11_magic_numbers() {
  # magic: 7 (line2), 2 and 3 (line5) = 3. 42 is a named const; 0/1 excluded;
  # 8080 lives inside a string; identifiers like x2 are not literals.
  local n
  n="$(printf 'const MAX = 42;\nif (x == 7) {}\nfor (i=0;i<1;i++){}\nlet s = "port 8080";\narr[2] = 3;\n' | cm_magic_numbers)"
  [[ "$n" == "3" ]]
}
check "counter: cm_magic_numbers excludes const/0/1/strings/identifiers" t11_magic_numbers

# Multiline-aware stripping + context exclusion (lang-parameterised). Each case
# below would leak digits under the old line-wise sed; all must report 0.
t11_magic_block_comment() {
  # block comment spanning lines: license header digits must not count
  [[ "$(printf '/*\n Copyright 2024 Acme\n build 1729 rev 42\n*/\n' | cm_magic_numbers csharp)" == "0" ]]
}
check "counter: cm_magic_numbers ignores /* */ block comments" t11_magic_block_comment

t11_magic_verbatim_string() {
  # C# verbatim string spanning lines (embedded SQL)
  [[ "$(printf 'var sql = @"\n  SELECT * FROM t WHERE id = 42\n  LIMIT 100";\n' | cm_magic_numbers csharp)" == "0" ]]
}
check "counter: cm_magic_numbers ignores multiline verbatim @\"\"" t11_magic_verbatim_string

t11_magic_raw_string() {
  # C# 11 raw string literal spanning lines
  [[ "$(printf 'var j = """\n { "port": 8080 }\n """;\n' | cm_magic_numbers csharp)" == "0" ]]
}
check "counter: cm_magic_numbers ignores raw \"\"\"...\"\"\" strings" t11_magic_raw_string

t11_magic_enum_body() {
  # enum members are named constants — the whole body is excluded
  [[ "$(printf 'enum E\n{\n    A = 100,\n    B = 200,\n}\n' | cm_magic_numbers csharp)" == "0" ]]
}
check "counter: cm_magic_numbers ignores enum body members" t11_magic_enum_body

t11_magic_attribute() {
  # attribute args are not magic; a line starting with [ is excluded
  [[ "$(printf '[Range(1, 100)]\n[MaxLength(255)]\n' | cm_magic_numbers csharp)" == "0" ]]
}
check "counter: cm_magic_numbers ignores attribute args" t11_magic_attribute

t11_magic_property_init() {
  [[ "$(printf 'public int Port { get; set; } = 8080;\n' | cm_magic_numbers csharp)" == "0" ]]
}
check "counter: cm_magic_numbers ignores auto-property initializers" t11_magic_property_init

t11_magic_indexer_kept() {
  # an indexer is NOT an attribute — arr[2] = 3 still yields two literals (2, 3)
  [[ "$(printf 'arr[2] = 3;\n' | cm_magic_numbers csharp)" == "2" ]]
}
check "counter: cm_magic_numbers keeps indexer literals (not attributes)" t11_magic_indexer_kept

t11_magic_ts_template() {
  # TS template literal spanning lines
  [[ "$(printf 'const s = `\n  port 8080\n  max 9999`;\n' | cm_magic_numbers typescript)" == "0" ]]
}
check "counter: cm_magic_numbers ignores TS template literals" t11_magic_ts_template

t11_magic_ts_array_literal() {
  # a leading [ is a C# attribute, but in TS/generic it's an array literal — its
  # numbers must still count (the attribute exclusion is C#-only)
  [[ "$(printf '  [12, 34],\n' | cm_magic_numbers typescript)" == "2" ]]
}
check "counter: cm_magic_numbers keeps TS array-literal numbers" t11_magic_ts_array_literal

t11_max_nesting() {
  local d
  d="$(printf 'fn(){\n if(a){\n  for(){\n   x;\n  }\n }\n}\n' | cm_max_nesting)"
  [[ "$d" == "3" ]]
}
check "counter: cm_max_nesting returns deepest brace level" t11_max_nesting

t11_max_nesting_flat() {
  [[ "$(printf 'a;\nb;\n' | cm_max_nesting)" == "0" ]]
}
check "counter: cm_max_nesting → 0 with no braces" t11_max_nesting_flat

t11_doc_ratio() {
  [[ "$(cm_doc_ratio 3 4)" == "75.0" ]] && [[ "$(cm_doc_ratio 0 0)" == "100.0" ]]
}
check "counter: cm_doc_ratio percentage; empty surface → 100.0" t11_doc_ratio

# ---------------------------------------------------------------------------
# SECTION 12 — RM-148 adapters (C# + TS) over real fixtures
# ---------------------------------------------------------------------------
# Purpose: the grep/awk/lizard metrics run end-to-end against a fixture repo.
# Values are asserted where the tool is deterministic and present (grep always;
# lizard is installed → param_count is real). The output contract is one
# `metric:value` line per function.
echo "=== Section 12: RM-148 adapters (fixtures) ==="

# shellcheck source=../cli/lib/adapter-csharp.sh
source "$OCTOPUS_DIR/cli/lib/adapter-csharp.sh"
# shellcheck source=../cli/lib/adapter-typescript.sh
source "$OCTOPUS_DIR/cli/lib/adapter-typescript.sh"

CS_FIX=$(mktemp -d); FIXTURES+=("$CS_FIX")
cat > "$CS_FIX/Sample.cs" <<'EOF'
public class Foo {
    // TODO: refactor
    [Obsolete]
    public int Bar(int a, int b) {
        if (a == 42) { return 0; }
        #pragma warning disable CS1591
        return b;
    }
}
EOF

t12_cs_todo()         { [[ "$(cm_adapter_csharp_todo_markers "$CS_FIX")"  == "todo_markers:1" ]]; }
t12_cs_deprecations() { [[ "$(cm_adapter_csharp_deprecations "$CS_FIX")"  == "deprecations:1" ]]; }
t12_cs_suppressions() { [[ "$(cm_adapter_csharp_suppressions "$CS_FIX")"  == "suppressions:1" ]]; }
t12_cs_magic()        { [[ "$(cm_adapter_csharp_magic_numbers "$CS_FIX")" == "magic_numbers:1" ]]; }
t12_cs_nesting()      { [[ "$(cm_adapter_csharp_nesting_depth "$CS_FIX")" == "nesting_depth:3" ]]; }
t12_cs_param()        { [[ "$(cm_adapter_csharp_param_count "$CS_FIX")"   == "param_count:2.0" ]]; }
t12_cs_doc()          { [[ "$(cm_adapter_csharp_doc_coverage "$CS_FIX")"  == "doc_coverage:0.0" ]]; }
check "adapter(C#): todo_markers counts TODO"          t12_cs_todo
check "adapter(C#): deprecations counts [Obsolete]"    t12_cs_deprecations
check "adapter(C#): suppressions counts #pragma disable" t12_cs_suppressions
check "adapter(C#): magic_numbers excludes 0, counts 42" t12_cs_magic
check "adapter(C#): nesting_depth = 3"                 t12_cs_nesting

# Generated code lives in the source tree but must never count toward metrics.
CS_GEN=$(mktemp -d); FIXTURES+=("$CS_GEN")
cat > "$CS_GEN/Hand.cs" <<'EOF'
public class Hand { public int F() { return 42; } }
EOF
mkdir -p "$CS_GEN/Migrations"
cat > "$CS_GEN/Migrations/0001_Init.cs" <<'EOF'
b.Property<string>("Name").HasMaxLength(255);
b.Property<decimal>("Total").HasColumnType("decimal(18,2)");
b.Property<int>("Code").HasDefaultValue(9999);
EOF
cat > "$CS_GEN/Model.Designer.cs" <<'EOF'
modelBuilder.Entity("X").Property<int>("Y").HasMaxLength(512).HasPrecision(38);
EOF
t12_cs_magic_prunes_generated() {
  # only Hand.cs's 42 is a real magic number; Migrations/ + *.Designer.cs ignored
  [[ "$(cm_adapter_csharp_magic_numbers "$CS_GEN")" == "magic_numbers:1" ]]
}
check "adapter(C#): magic_numbers prunes Migrations/ + *.Designer.cs" t12_cs_magic_prunes_generated
check "adapter(C#): param_count = 2.0 (lizard)"        t12_cs_param
check "adapter(C#): doc_coverage = 0.0 (no ///)"       t12_cs_doc

t12_cs_run_emits_all() {
  local out; out="$(cm_adapter_csharp_run "$CS_FIX" 2>/dev/null)"
  for m in coverage complexity module_size dependency_cycles \
           todo_markers deprecations dead_code suppressions \
           nesting_depth param_count magic_numbers lint_density doc_coverage; do
    grep -qE "^${m}:" <<<"$out" || return 1
  done
}
check "adapter(C#): _run emits all 13 metric lines" t12_cs_run_emits_all

TS_FIX=$(mktemp -d); FIXTURES+=("$TS_FIX")
cat > "$TS_FIX/sample.ts" <<'EOF'
/** documented */
export function foo(x: number, y: number) {
  // TODO later
  if (x === 7) { return 0; }
  return y;
}
export const bar = 1;
EOF

t12_ts_todo()    { [[ "$(cm_adapter_typescript_todo_markers "$TS_FIX")"  == "todo_markers:1" ]]; }
t12_ts_magic()   { [[ "$(cm_adapter_typescript_magic_numbers "$TS_FIX")" == "magic_numbers:1" ]]; }
t12_ts_nesting() { [[ "$(cm_adapter_typescript_nesting_depth "$TS_FIX")" == "nesting_depth:2" ]]; }
t12_ts_param()   { [[ "$(cm_adapter_typescript_param_count "$TS_FIX")"   == "param_count:2.0" ]]; }
t12_ts_doc()     { [[ "$(cm_adapter_typescript_doc_coverage "$TS_FIX")"  == "doc_coverage:50.0" ]]; }
check "adapter(TS): todo_markers counts TODO"        t12_ts_todo
check "adapter(TS): magic_numbers = 1 (7 only)"      t12_ts_magic
check "adapter(TS): nesting_depth = 2"               t12_ts_nesting
check "adapter(TS): param_count = 2.0 (lizard)"      t12_ts_param
check "adapter(TS): doc_coverage = 50.0 (1 of 2 exports)" t12_ts_doc

t12_ts_run_emits_all() {
  local out; out="$(cm_adapter_typescript_run "$TS_FIX" 2>/dev/null)"
  for m in coverage complexity module_size dependency_cycles \
           todo_markers deprecations dead_code suppressions \
           nesting_depth param_count magic_numbers lint_density doc_coverage; do
    grep -qE "^${m}:" <<<"$out" || return 1
  done
}
check "adapter(TS): _run emits all 13 metric lines" t12_ts_run_emits_all

# ---------------------------------------------------------------------------
# SECTION 13 — RM-149 hotspots (churn × complexity)
# ---------------------------------------------------------------------------
# Purpose: the decay metric joins git churn with per-file complexity. The two
# pure cores — churn aggregation from `git log --numstat` and the quadrant
# count — are fixture-tested; the adapter wires git + lizard.
echo "=== Section 13: RM-149 hotspots ==="

t13_git_churn_aggregates() {
  # added+deleted summed per path; binary (`-`) rows ignored; repeated paths add.
  local out
  out="$(printf '12\t3\tsrc/a.ts\n0\t5\tsrc/b.ts\n4\t1\tsrc/a.ts\n-\t-\tlogo.png\n' | cm_git_churn)"
  [[ "$(awk '$2=="src/a.ts"{print $1}' <<<"$out")" == "20" ]] &&
  [[ "$(awk '$2=="src/b.ts"{print $1}' <<<"$out")" == "5" ]] &&
  ! grep -q "logo.png" <<<"$out"
}
check "hotspots: cm_git_churn sums added+deleted per file, skips binary" t13_git_churn_aggregates

t13_hotspot_quadrant() {
  local cf xf; cf="$(mktemp)"; xf="$(mktemp)"; FIXTURES+=("$cf" "$xf")
  printf '20\tsrc/a.ts\n5\tsrc/b.ts\n30\tsrc/c.ts\n' > "$cf"   # churn
  printf '18\tsrc/a.ts\n2\tsrc/b.ts\n3\tsrc/c.ts\n'  > "$xf"   # ccn
  # threshold churn>=10 AND ccn>=10: only a.ts (20,18). b.ts low churn; c.ts low ccn.
  [[ "$(cm_hotspot_count 10 10 "$cf" "$xf")" == "1" ]]
}
check "hotspots: cm_hotspot_count counts high-churn AND high-complexity files" t13_hotspot_quadrant

t13_hotspot_none() {
  local cf xf; cf="$(mktemp)"; xf="$(mktemp)"; FIXTURES+=("$cf" "$xf")
  printf '3\tsrc/a.ts\n' > "$cf"; printf '2\tsrc/a.ts\n' > "$xf"
  [[ "$(cm_hotspot_count 10 10 "$cf" "$xf")" == "0" ]]
}
check "hotspots: cm_hotspot_count → 0 when nothing in the quadrant" t13_hotspot_none

t13_field_or_default() {
  # Unset → default; set → configured value (project layer).
  local d s; local proj; proj="$(mktemp)"; FIXTURES+=("$proj")
  d="$(CM_WORKSPACE_YML=/nonexistent CM_PERSONAL_YML=/nonexistent CM_PROJECT_YML=/nonexistent \
        cm_field_or hotspots window_days 90)"
  printf 'code_metrics:\n  hotspots:\n    window_days: 30\n' > "$proj"
  s="$(CM_WORKSPACE_YML=/nonexistent CM_PERSONAL_YML=/nonexistent CM_PROJECT_YML="$proj" \
        cm_field_or hotspots window_days 90)"
  [[ "$d" == "90" && "$s" == "30" ]]
}
check "hotspots: cm_field_or returns default when unset, value when set" t13_field_or_default

t13_adapter_emits_hotspots() {
  # Integration shape only: with no C# history/files the value is 0, but the
  # contract is a single hotspots:<n> line.
  grep -qE '^hotspots:[0-9]+$' <<<"$(cm_adapter_csharp_hotspots "$CS_FIX" 2>/dev/null)"
}
check "hotspots: cm_adapter_csharp_hotspots emits hotspots:<n>" t13_adapter_emits_hotspots

# ---------------------------------------------------------------------------
# SECTION 14 — RM-150 perf_risk scanner (info-only)
# ---------------------------------------------------------------------------
# Purpose: a static, heuristic proxy for load risk — risky calls inside loops,
# nested loops (O(n²)), allocations inside loops. High false-positive by nature,
# so it is reported as `info` and never gates. The brace-depth scanner core is
# fixture-tested; the adapter supplies per-language patterns.
echo "=== Section 14: RM-150 perf_risk scanner ==="

t14_perf_scan_counts() {
  # await/.find inside a loop (1) + nested loop (1) + new X inside a loop (1) = 3.
  local n
  n="$(printf '%s\n' \
    'for (const u of users) {' \
    '  await db.find(u.id);' \
    '  for (const t of u.tags) {' \
    '    new Thing();' \
    '  }' \
    '}' \
    | cm_perf_scan '(^|[^A-Za-z])(for|foreach|while)([^A-Za-z]|$)|[.](forEach|map)[(]' 'await|[.]find[(]|new [A-Z]')"
  [[ "$n" == "3" ]]
}
check "perf: cm_perf_scan counts risk-in-loop + nested-loop + alloc-in-loop" t14_perf_scan_counts

t14_perf_scan_outside_loop_zero() {
  # risky calls with no enclosing loop must not count.
  local n
  n="$(printf '%s\n' 'await db.find(1);' 'new Thing();' \
    | cm_perf_scan '(^|[^A-Za-z])(for|while)([^A-Za-z]|$)' 'await|new [A-Z]')"
  [[ "$n" == "0" ]]
}
check "perf: cm_perf_scan ignores risky calls outside any loop" t14_perf_scan_outside_loop_zero

t14_perf_adapter_info_only() {
  # Adapter emits perf_risk:<n>; registry marks it info (never gated).
  grep -qE '^perf_risk:[0-9]+$' <<<"$(cm_adapter_typescript_perf_risk "$TS_FIX" 2>/dev/null)" &&
  [[ "$(cm_metric_spec perf_risk)" == "info|perf_risk|" ]]
}
check "perf: adapter emits perf_risk:<n>, registry is info-only" t14_perf_adapter_info_only

# ---------------------------------------------------------------------------
# SECTION 15 — baseline.json assembly (cm_emit_baseline_json)  [RM-148/149/150]
# ---------------------------------------------------------------------------
# Purpose: the writer-Action produces baseline.json from the SAME adapter output
# (single source of truth, no YAML re-implementation drift). cm_emit_baseline_json
# turns the metric:value stream + commit/timestamp into the flat JSON record the
# orphan-ref stores, so new metrics become vs_baseline-capable for free.
echo "=== Section 15: baseline.json assembly ==="

t15_emit_baseline_json() {
  local out
  out="$(printf 'coverage:78.5\ncomplexity:9\ntodo_markers:3\nperf_risk:2\n' \
    | cm_emit_baseline_json abc123 2026-06-06T00:00:00Z)"
  [[ "$out" == '{"commit":"abc123","timestamp":"2026-06-06T00:00:00Z","coverage":78.5,"complexity":9,"todo_markers":3,"perf_risk":2}' ]]
}
check "baseline: cm_emit_baseline_json emits flat JSON with commit+timestamp+metrics" t15_emit_baseline_json

t15_emit_baseline_json_nonnumeric_zeroed() {
  # A non-numeric/garbage value must not break the JSON — coerced to 0.
  local out
  out="$(printf 'coverage:n/a\ncomplexity:9\n' | cm_emit_baseline_json x y)"
  [[ "$out" == '{"commit":"x","timestamp":"y","coverage":0,"complexity":9}' ]]
}
check "baseline: non-numeric metric value coerced to 0 (valid JSON)" t15_emit_baseline_json_nonnumeric_zeroed

# ---------------------------------------------------------------------------
echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
