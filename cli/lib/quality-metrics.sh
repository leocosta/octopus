#!/usr/bin/env bash
# cli/lib/quality-metrics.sh — `octopus quality-metrics` subcommand (RM-147).
# Dispatched by cli/octopus.sh. Sources the deterministic core and the adapter,
# then orchestrates: stack detection → adapter run → dual-delta → threshold →
# optional LLM curation marker.
#
# Following the hygiene.sh / knowledge-hygiene.sh split pattern:
#   cli/lib/quality-metrics.sh     — command entry (this file)
#   cli/lib/quality-metrics-lib.sh — deterministic core (pure functions)
#   cli/lib/adapter-csharp.sh      — C# metric adapter
#   cli/lib/adapter-typescript.sh  — TypeScript metric adapter

QM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./quality-metrics-lib.sh
source "$QM_LIB_DIR/quality-metrics-lib.sh"

QM_STACK=""
QM_METRIC=""
QM_VERBOSE=0

_qm_usage() {
  echo "usage: octopus quality-metrics [--stack <csharp|typescript>] [--metric <name>] [--verbose]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)   QM_STACK="${2:-}"; shift 2 ;;
    --metric)  QM_METRIC="${2:-}"; shift 2 ;;
    --verbose) QM_VERBOSE=1; shift ;;
    -h|--help) _qm_usage; exit 0 ;;
    *)
      echo "Unknown quality-metrics option: $1" >&2
      _qm_usage; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Stack detection
# ---------------------------------------------------------------------------
if [[ -z "$QM_STACK" ]]; then
  # Try to use _detect_stack from setup.sh if available
  SETUP_SH="$QM_LIB_DIR/setup.sh"
  if [[ -f "$SETUP_SH" ]]; then
    eval "$(sed -n '/^_detect_stack()/,/^}/p' "$SETUP_SH" 2>/dev/null || true)"
  fi

  if declare -f _detect_stack &>/dev/null; then
    DETECTED="$(_detect_stack "$PWD")"
    if grep -q "stack-csharp" <<<"$DETECTED"; then
      QM_STACK="csharp"
    elif grep -q "stack-typescript" <<<"$DETECTED"; then
      QM_STACK="typescript"
    fi
  fi

  # Fallback: direct filesystem sniff
  if [[ -z "$QM_STACK" ]]; then
    if find "$PWD" -name '*.csproj' -not -path '*/obj/*' | grep -q .; then
      QM_STACK="csharp"
    elif [[ -f "$PWD/package.json" ]]; then
      QM_STACK="typescript"
    fi
  fi
fi

if [[ -z "$QM_STACK" ]]; then
  echo "quality-metrics: could not detect stack (no *.csproj or package.json found)" >&2
  echo "Use --stack csharp|typescript to override." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Load adapter
# ---------------------------------------------------------------------------
ADAPTER_SCRIPT="$QM_LIB_DIR/adapter-${QM_STACK}.sh"
if [[ ! -f "$ADAPTER_SCRIPT" ]]; then
  echo "quality-metrics: no adapter for stack '$QM_STACK'" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ADAPTER_SCRIPT"

# ---------------------------------------------------------------------------
# Fetch orphan-ref baseline (read-only; never writes)
# ---------------------------------------------------------------------------
BASELINE_JSON=""
if git fetch origin "refs/octopus/quality-metrics:refs/octopus/quality-metrics" \
    --no-tags --quiet 2>/dev/null; then
  BASELINE_JSON="$(git show refs/octopus/quality-metrics:baseline.json 2>/dev/null || true)"
fi

# ---------------------------------------------------------------------------
# Run adapter to get current branch metrics
# ---------------------------------------------------------------------------
ADAPTER_FN="qm_adapter_${QM_STACK}_run"
if [[ -n "$QM_METRIC" ]]; then
  # Validate that a per-metric function exists
  if declare -f "qm_adapter_${QM_STACK}_${QM_METRIC}" &>/dev/null; then
    ADAPTER_FN="qm_adapter_${QM_STACK}_${QM_METRIC}"
  fi
fi

CURRENT_METRICS="$("$ADAPTER_FN" "$PWD")"

# ---------------------------------------------------------------------------
# Compute deltas, apply thresholds, print report
# ---------------------------------------------------------------------------
echo "=== quality-metrics report ==="
echo "stack:  $QM_STACK"
echo "commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
echo ""

BREACH_FOUND=0

while IFS=: read -r metric current; do
  [[ -z "$metric" ]] && continue

  # Resolve baseline value for this metric
  baseline_val="$(qm_parse_baseline "$BASELINE_JSON" "$metric")"

  # Load threshold config and pick the right threshold function
  absolute_threshold=""
  threshold_fn="qm_check_threshold"
  case "$metric" in
    coverage)
      absolute_threshold="$(qm_field "coverage" "min")"
      threshold_fn="qm_check_threshold"
      ;;
    complexity)
      absolute_threshold="$(qm_field "complexity" "max")"
      threshold_fn="qm_check_threshold_max"
      ;;
    module_size)
      absolute_threshold="$(qm_field "module_size" "max")"
      threshold_fn="qm_check_threshold_max"
      ;;
    dependency_cycles)
      absolute_threshold="$(qm_field "dependencies" "cycles_allowed")"
      threshold_fn="qm_check_threshold_max"
      ;;
  esac

  REPORT="$(qm_format_report "$metric" "$current" "$baseline_val" "$absolute_threshold" "$threshold_fn")"
  echo "$REPORT"
  grep -q "curation:needed" <<<"$REPORT" && BREACH_FOUND=1

done <<<"$CURRENT_METRICS"

echo ""

if [[ "$BREACH_FOUND" -eq 1 ]]; then
  echo "--- threshold breach detected ---"
  echo "curation:needed — invoke the low-cost model for regression analysis"
  echo "Run /octopus:quality-metrics to trigger curation (Haiku-class model)."
else
  echo "--- all metrics within threshold ---"
  echo "No LLM invocation required (≈0 tokens)."
fi
