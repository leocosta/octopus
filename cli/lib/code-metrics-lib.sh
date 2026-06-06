#!/usr/bin/env bash
# cli/lib/code-metrics-lib.sh — code-metrics deterministic core (RM-147).
#
# Provides:
#   cm_override  — read one field from a nested code_metrics: block in a YAML file
#   cm_field     — resolve a metric field across layers (default < workspace < personal < project)
#   cm_compute_delta   — compute dual delta (vs_baseline + vs_main)
#   cm_check_threshold / cm_check_threshold_max — ratchet + absolute threshold rule
#   cm_parse_baseline  — extract a metric value from a baseline.json string
#   cm_format_report   — format one metric line; emit curation:needed on breach
#
# Sourced by cli/lib/code-metrics.sh (the octopus code-metrics subcommand)
# and by tests/test_code_metrics.sh.
#
# Config-file environment overrides (for testing):
#   CM_PROJECT_YML   — project manifest   (default: $PWD/.octopus.yml)
#   CM_PERSONAL_YML  — personal manifest  (default: ${XDG_CONFIG_HOME:-$HOME/.config}/octopus/.octopus.yml)
#   CM_WORKSPACE_YML — workspace manifest (default: resolved from project manifest's workspace: key)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Reject any value that is not a plain number (integer or decimal, optional
# sign). Security boundary: config values (cm_field) and baseline values
# (cm_parse_baseline) are attacker-influenceable — a malicious .octopus.yml
# layer or a tampered orphan ref must never reach awk as program text. Every
# numeric value is validated here AND passed to awk via -v bindings (data, not
# code) before any arithmetic. Returns 0 if numeric.
cm_is_numeric() {
  [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
}

# Reject any value that is not a well-formed `dotnet test --filter` expression.
# Security boundary (mirrors cm_is_numeric): coverage.test_filter comes from a
# config layer (attacker-influenceable .octopus.yml) and is embedded in the
# command string handed to `dotnet-coverage collect`. dotnet-coverage tokenises
# that string itself (no shell), so the residual risk is argument injection via a
# stray quote breaking out of `--filter "<value>"`. This allowlist covers the
# full filter grammar — identifiers, comparison (= != ~), boolean (& |),
# grouping ( ), and value chars — while excluding quotes, $, ;, backticks and
# slashes that could break tokenisation. Returns 0 if safe.
cm_is_safe_filter() {
  local re='^[A-Za-z0-9_.,=!~&|()+ -]+$'
  [[ "$1" =~ $re ]]
}

# ---------------------------------------------------------------------------
# Config resolver
# ---------------------------------------------------------------------------

# Read a single field from the code_metrics: block of a .octopus.yml file.
#   $1 — file path
#   $2 — metric name  (e.g. "coverage")
#   $3 — field name   (e.g. "min")
# Echoes the value, or nothing if absent. Pure awk, 2-space nested YAML.
# Scalar contract: values are plain scalars (integers or decimals), never
# inline-map flow style.
cm_override() {
  local file="$1" metric="$2" field="$3"
  [[ -f "$file" ]] || return 0
  awk -v metric="$metric" -v field="$field" '
    /^[^ \t#]/ { in_qm = ($0 ~ /^code_metrics:[[:space:]]*$/); in_metric = 0; next }
    in_qm && /^  [^ \t]/ {
      cur = $0; sub(/^  /, "", cur); sub(/:.*$/, "", cur)
      in_metric = (cur == metric); next
    }
    in_qm && in_metric && /^    [^ \t]/ {
      key = $0; sub(/^    /, "", key); sub(/:.*$/, "", key)
      if (key == field) {
        val = $0; sub(/^[^:]*:[[:space:]]*/, "", val); sub(/[[:space:]]+$/, "", val)
        print val; exit
      }
    }
  ' "$file"
}

# Resolve a code_metrics field with precedence:
#   default (empty) < workspace < personal < project   (project wins)
#
# This is the OPPOSITE of kr_field's order, where personal wins over project.
# Here the committed repo state is authoritative — a quality contract should
# not be silently overridden by an individual developer's personal config.
#
# Layer files are resolved from environment variables (injectable for tests):
#   CM_PROJECT_YML, CM_PERSONAL_YML, CM_WORKSPACE_YML
#
# The workspace layer is new work not present in kr_field: it reads
# $OCTOPUS_WORKSPACE_PATH/.octopus.yml when that variable is set, consistent
# with RM-069. CM_WORKSPACE_YML takes precedence over the auto-resolved path.
# Internal: resolve a field across layers (workspace < personal < project; project
# wins), returning the raw string value with no validation. Shared by cm_field
# (numeric) and cm_field_str (string).
_cm_resolve() {
  local metric="$1" field="$2"

  # Resolve file paths (injectable via env for tests)
  local project_yml="${CM_PROJECT_YML:-${KR_PROJECT_YML:-$PWD/.octopus.yml}}"
  local personal_yml="${CM_PERSONAL_YML:-${XDG_CONFIG_HOME:-$HOME/.config}/octopus/.octopus.yml}"

  # Workspace: honour CM_WORKSPACE_YML if set, else auto-resolve from workspace: key
  local workspace_yml="${CM_WORKSPACE_YML:-}"
  if [[ -z "$workspace_yml" && -n "${OCTOPUS_WORKSPACE_PATH:-}" ]]; then
    workspace_yml="$OCTOPUS_WORKSPACE_PATH/.octopus.yml"
  fi
  if [[ -z "$workspace_yml" && -f "$project_yml" ]]; then
    local ws_path
    ws_path="$(awk '/^workspace:[[:space:]]*/ {val=$0; sub(/^workspace:[[:space:]]*/,"",val); sub(/[[:space:]]+$/,"",val); print val}' "$project_yml")"
    [[ -n "$ws_path" ]] && workspace_yml="$ws_path/.octopus.yml"
  fi

  # Apply layers left to right: later overwrites earlier (project is last → wins)
  local val="" ov
  # Layer 1: workspace
  if [[ -n "$workspace_yml" ]]; then
    ov="$(cm_override "$workspace_yml" "$metric" "$field")"; [[ -n "$ov" ]] && val="$ov"
  fi
  # Layer 2: personal
  ov="$(cm_override "$personal_yml" "$metric" "$field")"; [[ -n "$ov" ]] && val="$ov"
  # Layer 3: project (wins)
  ov="$(cm_override "$project_yml" "$metric" "$field")"; [[ -n "$ov" ]] && val="$ov"

  printf '%s\n' "$val"
}

cm_field() {
  local metric="$1" field="$2" val
  val="$(_cm_resolve "$metric" "$field")"

  # Security boundary: a resolved config value flows into arithmetic. Reject
  # anything non-numeric so attacker-controlled config (any layer) can never be
  # interpreted as awk program text downstream.
  if [[ -n "$val" ]] && ! cm_is_numeric "$val"; then
    echo "cm_field: non-numeric value for ${metric}.${field}: $val" >&2
    return 1
  fi

  printf '%s\n' "$val"
}

# Resolve a numeric config field, falling back to a default when unset.
# Thin wrapper over cm_field for the common "config value or built-in default"
# pattern (e.g. the hotspots window/thresholds).
cm_field_or() {
  local v; v="$(cm_field "$1" "$2" 2>/dev/null || true)"
  printf '%s\n' "${v:-$3}"
}

# Resolve a string-valued config field (e.g. coverage.test_filter,
# coverage.settings) across the same layers as cm_field, WITHOUT numeric
# validation. Security: the returned value is attacker-influenceable (any config
# layer), so callers MUST pass it to subprocesses as a single quoted argv element
# — never interpolate it into shell or awk program text.
cm_field_str() {
  local v; v="$(_cm_resolve "$1" "$2")"
  # Strip one layer of surrounding quotes (YAML quoted scalars like "a!=b").
  v="${v%\"}"; v="${v#\"}"
  v="${v%\'}"; v="${v#\'}"
  printf '%s\n' "$v"
}

# ---------------------------------------------------------------------------
# Dual-delta engine
# ---------------------------------------------------------------------------

# Compute dual delta for a "higher is better" metric (e.g. coverage).
#   $1 — main_value    (local main HEAD)
#   $2 — branch_value  (current branch)
#   $3 — baseline_value (last-main baseline from orphan ref; empty = no record)
#
# Outputs two lines:
#   vs_baseline:<delta>    (branch - baseline; "n/a" if no baseline)
#   vs_main:<delta>        (branch - main)
#
# Positive delta = improvement; negative = regression.
cm_compute_delta() {
  local main_val="$1" branch_val="$2" baseline_val="$3"

  local vs_main vs_baseline
  vs_main="$(awk -v b="$branch_val" -v m="$main_val" 'BEGIN { printf "%g", (b+0) - (m+0) }')"

  if [[ -z "$baseline_val" ]]; then
    vs_baseline="n/a"
  else
    vs_baseline="$(awk -v b="$branch_val" -v x="$baseline_val" 'BEGIN { printf "%g", (b+0) - (x+0) }')"
  fi

  printf 'vs_baseline:%s\nvs_main:%s\n' "$vs_baseline" "$vs_main"
}

# ---------------------------------------------------------------------------
# Threshold rule — higher-is-better (coverage)
# ---------------------------------------------------------------------------

# Evaluate whether a "higher is better" metric passes its threshold.
#   $1 — metric name (informational)
#   $2 — current value (branch)
#   $3 — baseline value (may be empty → ratchet not applicable)
#   $4 — absolute_min threshold (may be empty → ratchet only)
#
# Returns 0 (OK) or 1 (breach).  Prints a reason to stdout on breach.
cm_check_threshold() {
  local metric="$1" current="$2" baseline="$3" absolute_min="$4"

  # Absolute check: current must be >= absolute_min if set
  if [[ -n "$absolute_min" ]]; then
    local ok
    ok="$(awk -v c="$current" -v m="$absolute_min" 'BEGIN { print (c+0 >= m+0) ? "1" : "0" }')"
    if [[ "$ok" == "0" ]]; then
      echo "breach: $metric current=$current is below absolute min=$absolute_min"
      return 1
    fi
    # Absolute satisfied → no ratchet on top
    return 0
  fi

  # Ratchet check: current must not be worse than baseline
  if [[ -n "$baseline" ]]; then
    local ok
    ok="$(awk -v c="$current" -v b="$baseline" 'BEGIN { print (c+0 >= b+0) ? "1" : "0" }')"
    if [[ "$ok" == "0" ]]; then
      echo "breach: $metric current=$current regressed vs baseline=$baseline"
      return 1
    fi
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Threshold rule — lower-is-better (complexity, module_size, dependency_cycles)
# ---------------------------------------------------------------------------

# Evaluate whether a "lower is better" metric passes its threshold.
#   $1 — metric name
#   $2 — current value
#   $3 — baseline value (may be empty)
#   $4 — absolute_max threshold (may be empty → ratchet only)
#
# When an absolute_max is set and the current value satisfies it, the
# absolute check is the authoritative verdict — ratchet is not applied on
# top of it.  Ratchet applies only when no absolute threshold is configured.
#
# Returns 0 (OK) or 1 (breach).
cm_check_threshold_max() {
  local metric="$1" current="$2" baseline="$3" absolute_max="$4"

  # Absolute check: current must be <= absolute_max if set
  if [[ -n "$absolute_max" ]]; then
    local ok
    ok="$(awk -v c="$current" -v m="$absolute_max" 'BEGIN { print (c+0 <= m+0) ? "1" : "0" }')"
    if [[ "$ok" == "0" ]]; then
      echo "breach: $metric current=$current exceeds absolute max=$absolute_max"
      return 1
    fi
    # Absolute satisfied → no ratchet on top
    return 0
  fi

  # Ratchet check: current must not be worse (higher) than baseline
  if [[ -n "$baseline" ]]; then
    local ok
    ok="$(awk -v c="$current" -v b="$baseline" 'BEGIN { print (c+0 <= b+0) ? "1" : "0" }')"
    if [[ "$ok" == "0" ]]; then
      echo "breach: $metric current=$current regressed vs baseline=$baseline"
      return 1
    fi
  fi

  return 0
}

# Threshold rule — info-only metrics (e.g. perf_risk).
# Always passes (returns 0): the value is reported via the delta line but never
# produces a curation:needed marker. Used by the dispatch loop for registry
# entries whose direction is "info" — high-false-positive heuristics that must
# inform, not gate (RM-150).
cm_check_noop() {
  return 0
}

# ---------------------------------------------------------------------------
# RM-148 counter helpers — deterministic, fixture-testable
# ---------------------------------------------------------------------------
# These are the pure cores of the v2 pack metrics. Adapters feed them language
# specifics (file extensions, grep patterns); the heuristic lives here once.

# Common build/vendor dirs that must never count toward source metrics.
CM_PRUNE_DIRS=(--exclude-dir=node_modules --exclude-dir=obj --exclude-dir=bin
  --exclude-dir=.git --exclude-dir=dist --exclude-dir=.next --exclude-dir=.claude)

# Count source lines matching an ERE under a path (file or dir), pruning
# build/vendor dirs. A line with multiple matches counts once (line-granular).
#   $1   — extended regex
#   $2   — path (file or directory)
#   $3.. — optional extra grep args (e.g. --include='*.cs' to scope a language)
# Echoes the count (0 for an absent path).
cm_count_matches() {
  local ere="$1" path="$2"; shift 2
  [[ -e "$path" ]] || { echo 0; return 0; }
  grep -rIE "${CM_PRUNE_DIRS[@]}" "$@" "$ere" "$path" 2>/dev/null | wc -l | tr -d ' '
}

# Count "magic numbers" on stdin: numeric literals that are not 0/1/-1, not part
# of an identifier, not inside a string, and not on a named-constant declaration
# line (const/readonly/enum/final/#define). Heuristic — strings and comments are
# stripped line-wise before token extraction.
# Reads stdin, echoes the count.
cm_magic_numbers() {
  sed -E -e 's#//.*$##' -e 's/"[^"]*"//g' -e "s/'[^']*'//g" \
    | grep -vE '(^|[^A-Za-z_])(const|readonly|enum|final)([^A-Za-z_]|$)|#define' \
    | grep -oE '(^|[^A-Za-z0-9_.])-?[0-9]+(\.[0-9]+)?' \
    | grep -oE '\-?[0-9]+(\.[0-9]+)?' \
    | grep -vxE '\-?[01]' \
    | wc -l | tr -d ' '
}

# Maximum brace-nesting depth on stdin (char-by-char running max of '{' minus
# '}'). Heuristic — braces inside strings/comments are not discounted.
# Reads stdin, echoes the deepest level (0 if none).
cm_max_nesting() {
  awk '
    {
      n = length($0)
      for (i = 1; i <= n; i++) {
        ch = substr($0, i, 1)
        if (ch == "{") { depth++; if (depth > max) max = depth }
        else if (ch == "}") { if (depth > 0) depth-- }
      }
    }
    END { print max + 0 }
  '
}

# Documentation-coverage percentage from two counts (pure arithmetic).
#   $1 — documented public symbols
#   $2 — total public symbols
# total <= 0 → 100.0 (no public surface ⇒ nothing undocumented).
cm_doc_ratio() {
  awk -v d="$1" -v t="$2" 'BEGIN {
    if (t + 0 <= 0) { print "100.0" } else { printf "%.1f", (d / t) * 100 }
  }'
}

# ---------------------------------------------------------------------------
# RM-149 hotspots — churn × complexity (decay)
# ---------------------------------------------------------------------------

# Aggregate per-file churn from `git log --numstat --format=` on stdin.
# numstat rows are: <added>\t<deleted>\t<path>; binary files show `-` and are
# skipped. Repeated paths accumulate.
# Reads stdin, emits one `<churn>\t<path>` line per file.
cm_git_churn() {
  awk '
    NF == 3 && $1 != "-" { churn[$3] += $1 + $2 }
    END { for (f in churn) printf "%d\t%s\n", churn[f], f }
  '
}

# Count files in the high-churn AND high-complexity quadrant.
#   $1 — churn threshold (>=)
#   $2 — ccn threshold   (>=)
#   $3 — churn file: "<churn>\t<path>" lines (from cm_git_churn)
#   $4 — ccn file:   "<ccn>\t<path>"   lines (max CCN per file)
# Echoes the count. A file must appear in BOTH and clear BOTH thresholds.
cm_hotspot_count() {
  local ct="$1" xt="$2" churn_file="$3" ccn_file="$4"
  awk -v ct="$ct" -v xt="$xt" '
    FNR == NR { churn[$2] = $1; next }
    { if (($2 in churn) && churn[$2] + 0 >= ct + 0 && $1 + 0 >= xt + 0) c++ }
    END { print c + 0 }
  ' "$churn_file" "$ccn_file"
}

# ---------------------------------------------------------------------------
# RM-150 perf_risk — static load-risk proxy (info-only)
# ---------------------------------------------------------------------------

# Scan stdin for performance-risk signals and echo the total count:
#   - a risky call (query/await/allocation) inside a loop body
#   - a nested loop (O(n²) candidate)
#   $1 — loop-opener ERE
#   $2 — risky-call ERE
# Heuristic, brace-depth based: a loop is "active" from the `{` on its opener
# line until the matching `}`. Counting for a line uses the loop nesting
# established by PRIOR lines (so the opener line itself is not "inside" itself).
# High false-positive by design — the caller reports it as info, never gates.
cm_perf_scan() {
  # Patterns are passed via the environment, not awk -v: -v applies backslash
  # escape processing that would corrupt regex metacharacters. ENVIRON is raw.
  CM_PS_LOOP="$1" CM_PS_RISK="$2" awk '
    BEGIN { loopre = ENVIRON["CM_PS_LOOP"]; riskre = ENVIRON["CM_PS_RISK"] }
    {
      is_loop = ($0 ~ loopre)
      is_risk = ($0 ~ riskre)
      if (is_risk && top > 0) count++       # risky call inside a loop
      if (is_loop && top > 0) count++       # nested loop (O(n^2) candidate)

      pushed = 0
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c == "{") {
          depth++
          if (is_loop && !pushed) { loopdepth[++top] = depth; pushed = 1 }
        } else if (c == "}") {
          if (top > 0 && depth == loopdepth[top]) top--
          if (depth > 0) depth--
        }
      }
    }
    END { print count + 0 }
  '
}

# ---------------------------------------------------------------------------
# Metric registry — single source of truth for dispatch  (RM-148)
# ---------------------------------------------------------------------------

# Map a metric name to its dispatch spec: "direction|config_block|config_field".
#   direction — "higher" (higher is better, e.g. coverage), "lower" (lower is
#               better, e.g. complexity), or "info" (reported, never gated).
#   config_block / config_field — where its absolute threshold lives in the
#               code_metrics: block of .octopus.yml (empty for info metrics).
#
# This replaces the hardcoded case in code-metrics.sh: the dispatch loop reads
# the registry to pick cm_check_threshold (higher) / cm_check_threshold_max
# (lower) / skip (info) and to resolve the absolute threshold via cm_field.
# Adding a metric is a one-line entry here plus its adapter function.
# Unknown metric → empty string (caller skips it; no phantom dispatch).
cm_metric_spec() {
  case "$1" in
    # v1 (RM-147)
    coverage)          echo "higher|coverage|min" ;;
    complexity)        echo "lower|complexity|max" ;;
    module_size)       echo "lower|module_size|max" ;;
    dependency_cycles) echo "lower|dependencies|cycles_allowed" ;;
    # v2 pack (RM-148) — debt markers
    todo_markers)      echo "lower|todo_markers|max" ;;
    deprecations)      echo "lower|deprecations|max" ;;
    dead_code)         echo "lower|dead_code|max" ;;
    suppressions)      echo "lower|suppressions|max" ;;
    # v2 pack (RM-148) — readability counters
    nesting_depth)     echo "lower|nesting_depth|max" ;;
    param_count)       echo "lower|param_count|max" ;;
    magic_numbers)     echo "lower|magic_numbers|max" ;;
    lint_density)      echo "lower|lint_density|max" ;;
    # v2 pack (RM-148) — documentation
    doc_coverage)      echo "higher|doc_coverage|min" ;;
    # v3 (RM-149) — decay hotspots
    hotspots)          echo "lower|hotspots|max" ;;
    # v3 (RM-150) — perf risk proxy: info-only (high false-positive, never gated)
    perf_risk)         echo "info|perf_risk|" ;;
    *)                 return 0 ;;
  esac
}

# ---------------------------------------------------------------------------
# Orphan-ref record parsing
# ---------------------------------------------------------------------------

# Extract a metric value from a baseline.json string (flat single-line JSON).
#   $1 — JSON string (e.g. '{"coverage":78.5,"complexity":9}')
#   $2 — field name (e.g. "coverage")
#
# Echoes the numeric value, or empty if absent.
# Pure awk — no jq dependency.
cm_parse_baseline() {
  local json="$1" field="$2"
  [[ -z "$json" || -z "$field" ]] && return 0
  # Match "field":value where value is a number (int or float)
  awk -v field="$field" '
    {
      pattern = "\"" field "\":[[:space:]]*([0-9]+\\.?[0-9]*)"
      if (match($0, "\"" field "\":[[:space:]]*[0-9]+\\.?[0-9]*")) {
        seg = substr($0, RSTART, RLENGTH)
        sub(/^"[^"]*":[[:space:]]*/, "", seg)
        print seg
      }
    }
  ' <<<"$json"
}

# ---------------------------------------------------------------------------
# Baseline assembly (writer side)
# ---------------------------------------------------------------------------

# Turn an adapter `metric:value` stream (stdin) plus commit + timestamp into the
# flat baseline.json record stored on the orphan ref. Single source of truth:
# the writer-Action runs the adapter and pipes it here, so new metrics become
# vs_baseline-capable with no YAML re-implementation.
#   $1 — commit sha
#   $2 — ISO timestamp
# Non-numeric metric values are coerced to 0 so the JSON is always valid.
cm_emit_baseline_json() {
  awk -v commit="$1" -v ts="$2" '
    BEGIN { printf "{\"commit\":\"%s\",\"timestamp\":\"%s\"", commit, ts }
    /^[a-z_]+:/ {
      key = $0; sub(/:.*$/, "", key)
      val = $0; sub(/^[a-z_]+:/, "", val)
      if (val !~ /^-?[0-9]+(\.[0-9]+)?$/) val = 0
      printf ",\"%s\":%s", key, val
    }
    END { print "}" }
  '
}

# ---------------------------------------------------------------------------
# Report formatting (cost-contract guard)
# ---------------------------------------------------------------------------

# Format a single metric report line and emit curation:needed if a threshold
# breach is detected.  This is the seam the skill reads to decide whether to
# invoke the low-cost model.
#
#   $1 — metric name
#   $2 — current value (branch)
#   $3 — baseline value (may be empty)
#   $4 — absolute threshold (may be empty)
#   $5 — threshold function: "cm_check_threshold" or "cm_check_threshold_max"
#
# Output lines:
#   metric:<name> current:<val> vs_baseline:<d> vs_main:<d>
#   [curation:needed reason:<...>]    — only on breach
cm_format_report() {
  local metric="$1" current="$2" baseline="$3" absolute="$4" threshold_fn="${5:-cm_check_threshold}"

  # For this function, vs_main is the same as vs_baseline when we only have one
  # reference point (the caller passes baseline as the single comparator).
  local delta_line
  delta_line="$(cm_compute_delta "${baseline:-$current}" "$current" "$baseline")"
  local vs_baseline vs_main
  vs_baseline="$(grep "^vs_baseline:" <<<"$delta_line" | cut -d: -f2)"
  vs_main="$(grep "^vs_main:" <<<"$delta_line" | cut -d: -f2)"

  printf 'metric:%s current:%s vs_baseline:%s vs_main:%s\n' \
    "$metric" "$current" "$vs_baseline" "$vs_main"

  # Check threshold and emit curation marker on breach
  local breach_reason
  if ! breach_reason="$("$threshold_fn" "$metric" "$current" "$baseline" "$absolute" 2>&1)"; then
    printf 'curation:needed reason:%s\n' "$breach_reason"
  fi
}
