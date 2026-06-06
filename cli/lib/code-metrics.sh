#!/usr/bin/env bash
# cli/lib/code-metrics.sh — `octopus code-metrics` subcommand (RM-147).
# Dispatched by cli/octopus.sh. Sources the deterministic core and the adapter,
# then orchestrates: stack detection → adapter run → dual-delta → threshold →
# optional LLM curation marker.
#
# Following the hygiene.sh / knowledge-hygiene.sh split pattern:
#   cli/lib/code-metrics.sh     — command entry (this file)
#   cli/lib/code-metrics-lib.sh — deterministic core (pure functions)
#   cli/lib/adapter-csharp.sh   — C# metric adapter
#   cli/lib/adapter-typescript.sh — TypeScript metric adapter

CM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./code-metrics-lib.sh
source "$CM_LIB_DIR/code-metrics-lib.sh"

CM_STACK=""
CM_METRIC=""
CM_VERBOSE=0
CM_EMIT_BASELINE=0

_cm_usage() {
  echo "usage: octopus code-metrics [--stack <csharp|typescript>] [--metric <name>] [--verbose] [--emit-baseline]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)   CM_STACK="${2:-}"; shift 2 ;;
    --metric)  CM_METRIC="${2:-}"; shift 2 ;;
    --verbose) CM_VERBOSE=1; shift ;;
    --emit-baseline) CM_EMIT_BASELINE=1; shift ;;
    -h|--help) _cm_usage; exit 0 ;;
    *)
      echo "Unknown code-metrics option: $1" >&2
      _cm_usage; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Stack detection
# ---------------------------------------------------------------------------
if [[ -z "$CM_STACK" ]]; then
  # Try to use _detect_stack from setup.sh if available
  SETUP_SH="$CM_LIB_DIR/setup.sh"
  if [[ -f "$SETUP_SH" ]]; then
    eval "$(sed -n '/^_detect_stack()/,/^}/p' "$SETUP_SH" 2>/dev/null || true)"
  fi

  if declare -f _detect_stack &>/dev/null; then
    DETECTED="$(_detect_stack "$PWD")"
    if grep -q "stack-csharp" <<<"$DETECTED"; then
      CM_STACK="csharp"
    elif grep -q "stack-typescript" <<<"$DETECTED"; then
      CM_STACK="typescript"
    fi
  fi

  # Fallback: direct filesystem sniff
  if [[ -z "$CM_STACK" ]]; then
    if find "$PWD" -name '*.csproj' -not -path '*/obj/*' | grep -q .; then
      CM_STACK="csharp"
    elif [[ -f "$PWD/package.json" ]]; then
      CM_STACK="typescript"
    fi
  fi
fi

if [[ -z "$CM_STACK" ]]; then
  echo "code-metrics: could not detect stack (no *.csproj or package.json found)" >&2
  echo "Use --stack csharp|typescript to override." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Load adapter
# ---------------------------------------------------------------------------
ADAPTER_SCRIPT="$CM_LIB_DIR/adapter-${CM_STACK}.sh"
if [[ ! -f "$ADAPTER_SCRIPT" ]]; then
  echo "code-metrics: no adapter for stack '$CM_STACK'" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ADAPTER_SCRIPT"

# ---------------------------------------------------------------------------
# Fetch orphan-ref baseline (read-only; never writes)
# ---------------------------------------------------------------------------
BASELINE_JSON=""
if git fetch origin "refs/octopus/code-metrics:refs/octopus/code-metrics" \
    --no-tags --quiet 2>/dev/null; then
  BASELINE_JSON="$(git show refs/octopus/code-metrics:baseline.json 2>/dev/null || true)"
fi

# ---------------------------------------------------------------------------
# Run adapter to get current branch metrics
# ---------------------------------------------------------------------------
ADAPTER_FN="cm_adapter_${CM_STACK}_run"
if [[ -n "$CM_METRIC" ]]; then
  # Validate that a per-metric function exists
  if declare -f "cm_adapter_${CM_STACK}_${CM_METRIC}" &>/dev/null; then
    ADAPTER_FN="cm_adapter_${CM_STACK}_${CM_METRIC}"
  fi
fi

CURRENT_METRICS="$("$ADAPTER_FN" "$PWD")"

# ---------------------------------------------------------------------------
# --emit-baseline: print the flat baseline.json from this run and exit.
# Used by the writer-Action so the producer shares the adapters (no YAML
# re-implementation / drift). Skips the delta/threshold report entirely.
# ---------------------------------------------------------------------------
if [[ "$CM_EMIT_BASELINE" -eq 1 ]]; then
  cm_commit="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  cm_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cm_emit_baseline_json "$cm_commit" "$cm_ts" <<<"$CURRENT_METRICS"
  exit 0
fi

# ---------------------------------------------------------------------------
# Compute deltas, apply thresholds, print report
# ---------------------------------------------------------------------------
echo "=== code-metrics report ==="
echo "stack:  $CM_STACK"
echo "commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
echo ""

BREACH_FOUND=0

while IFS=: read -r metric current; do
  [[ -z "$metric" ]] && continue
  # Skip malformed adapter output: a metric name is lower_snake_case. This
  # guards against stray non-metric lines a tool may leak into the stream.
  [[ "$metric" =~ ^[a-z_]+$ ]] || continue

  # Resolve dispatch from the registry (single source of truth, RM-148):
  #   direction|config_block|config_field
  spec="$(cm_metric_spec "$metric")"
  if [[ -z "$spec" ]]; then
    # Unregistered metric — surface the raw value, no threshold dispatch.
    echo "metric:$metric current:$current vs_baseline:n/a vs_main:n/a (unregistered)"
    continue
  fi
  IFS='|' read -r cm_direction cm_block cm_field_name <<<"$spec"

  baseline_val="$(cm_parse_baseline "$BASELINE_JSON" "$metric")"

  # Pick the threshold function from the direction.
  case "$cm_direction" in
    higher) threshold_fn="cm_check_threshold" ;;
    lower)  threshold_fn="cm_check_threshold_max" ;;
    info|*) threshold_fn="cm_check_noop" ;;   # info-only: report, never gate
  esac

  # Resolve the optional absolute threshold (info metrics have no config field).
  absolute_threshold=""
  if [[ -n "$cm_field_name" ]]; then
    absolute_threshold="$(cm_field "$cm_block" "$cm_field_name" 2>/dev/null || true)"
  fi

  REPORT="$(cm_format_report "$metric" "$current" "$baseline_val" "$absolute_threshold" "$threshold_fn")"
  echo "$REPORT"
  grep -q "curation:needed" <<<"$REPORT" && BREACH_FOUND=1

done <<<"$CURRENT_METRICS"

echo ""

if [[ "$BREACH_FOUND" -eq 1 ]]; then
  echo "--- threshold breach detected ---"
  echo "curation:needed — invoke the low-cost model for regression analysis"
  echo "Run /octopus:code-metrics to trigger curation (Haiku-class model)."
else
  echo "--- all metrics within threshold ---"
  echo "No LLM invocation required (≈0 tokens)."
fi
