#!/usr/bin/env bash
# cli/lib/quality-metrics.sh — quality-metrics deterministic core (RM-147).
#
# Provides:
#   qm_override  — read one field from a nested quality_metrics: block in a YAML file
#   qm_field     — resolve a metric field across layers (default < workspace < personal < project)
#   qm_compute_delta   — compute dual delta (vs_baseline + vs_main)
#   qm_check_threshold / qm_check_threshold_max — ratchet + absolute threshold rule
#   qm_parse_baseline  — extract a metric value from a baseline.json string
#   qm_format_report   — format one metric line; emit curation:needed on breach
#
# Sourced by cli/lib/quality-metrics-cmd.sh (the octopus quality-metrics subcommand)
# and by tests/test_quality_metrics.sh.
#
# Config-file environment overrides (for testing):
#   QM_PROJECT_YML   — project manifest   (default: $PWD/.octopus.yml)
#   QM_PERSONAL_YML  — personal manifest  (default: ${XDG_CONFIG_HOME:-$HOME/.config}/octopus/.octopus.yml)
#   QM_WORKSPACE_YML — workspace manifest (default: resolved from project manifest's workspace: key)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Reject any value that is not a plain number (integer or decimal, optional
# sign). Security boundary: config values (qm_field) and baseline values
# (qm_parse_baseline) are attacker-influenceable — a malicious .octopus.yml
# layer or a tampered orphan ref must never reach awk as program text. Every
# numeric value is validated here AND passed to awk via -v bindings (data, not
# code) before any arithmetic. Returns 0 if numeric.
qm_is_numeric() {
  [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
}

# ---------------------------------------------------------------------------
# Config resolver
# ---------------------------------------------------------------------------

# Read a single field from the quality_metrics: block of a .octopus.yml file.
#   $1 — file path
#   $2 — metric name  (e.g. "coverage")
#   $3 — field name   (e.g. "min")
# Echoes the value, or nothing if absent. Pure awk, 2-space nested YAML.
# Scalar contract: values are plain scalars (integers or decimals), never
# inline-map flow style.
qm_override() {
  local file="$1" metric="$2" field="$3"
  [[ -f "$file" ]] || return 0
  awk -v metric="$metric" -v field="$field" '
    /^[^ \t#]/ { in_qm = ($0 ~ /^quality_metrics:[[:space:]]*$/); in_metric = 0; next }
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

# Resolve a quality_metrics field with precedence:
#   default (empty) < workspace < personal < project   (project wins)
#
# This is the OPPOSITE of kr_field's order, where personal wins over project.
# Here the committed repo state is authoritative — a quality contract should
# not be silently overridden by an individual developer's personal config.
#
# Layer files are resolved from environment variables (injectable for tests):
#   QM_PROJECT_YML, QM_PERSONAL_YML, QM_WORKSPACE_YML
#
# The workspace layer is new work not present in kr_field: it reads
# $OCTOPUS_WORKSPACE_PATH/.octopus.yml when that variable is set, consistent
# with RM-069. QM_WORKSPACE_YML takes precedence over the auto-resolved path.
qm_field() {
  local metric="$1" field="$2"

  # Resolve file paths (injectable via env for tests)
  local project_yml="${QM_PROJECT_YML:-${KR_PROJECT_YML:-$PWD/.octopus.yml}}"
  local personal_yml="${QM_PERSONAL_YML:-${XDG_CONFIG_HOME:-$HOME/.config}/octopus/.octopus.yml}"

  # Workspace: honour QM_WORKSPACE_YML if set, else auto-resolve from workspace: key
  local workspace_yml="${QM_WORKSPACE_YML:-}"
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
    ov="$(qm_override "$workspace_yml" "$metric" "$field")"; [[ -n "$ov" ]] && val="$ov"
  fi
  # Layer 2: personal
  ov="$(qm_override "$personal_yml" "$metric" "$field")"; [[ -n "$ov" ]] && val="$ov"
  # Layer 3: project (wins)
  ov="$(qm_override "$project_yml" "$metric" "$field")"; [[ -n "$ov" ]] && val="$ov"

  # Security boundary: a resolved config value flows into arithmetic. Reject
  # anything non-numeric so attacker-controlled config (any layer) can never be
  # interpreted as awk program text downstream.
  if [[ -n "$val" ]] && ! qm_is_numeric "$val"; then
    echo "qm_field: non-numeric value for ${metric}.${field}: $val" >&2
    return 1
  fi

  printf '%s\n' "$val"
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
qm_compute_delta() {
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
qm_check_threshold() {
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
qm_check_threshold_max() {
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

# ---------------------------------------------------------------------------
# Orphan-ref record parsing
# ---------------------------------------------------------------------------

# Extract a metric value from a baseline.json string (flat single-line JSON).
#   $1 — JSON string (e.g. '{"coverage":78.5,"complexity":9}')
#   $2 — field name (e.g. "coverage")
#
# Echoes the numeric value, or empty if absent.
# Pure awk — no jq dependency.
qm_parse_baseline() {
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
#   $5 — threshold function: "qm_check_threshold" or "qm_check_threshold_max"
#
# Output lines:
#   metric:<name> current:<val> vs_baseline:<d> vs_main:<d>
#   [curation:needed reason:<...>]    — only on breach
qm_format_report() {
  local metric="$1" current="$2" baseline="$3" absolute="$4" threshold_fn="${5:-qm_check_threshold}"

  # For this function, vs_main is the same as vs_baseline when we only have one
  # reference point (the caller passes baseline as the single comparator).
  local delta_line
  delta_line="$(qm_compute_delta "${baseline:-$current}" "$current" "$baseline")"
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
