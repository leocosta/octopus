#!/usr/bin/env bash
# cli/lib/adapter-typescript.sh — TypeScript quality-metrics adapter (RM-147).
#
# Implements the stack-agnostic metric contract for TypeScript/JavaScript repos.
# Called by cli/lib/quality-metrics-cmd.sh when stack=typescript.
#
# Output contract: one line per metric, format:
#   <metric_name>:<numeric_value>
#
# Tool pinning (v1):
#   coverage          — vitest --coverage → LCOV → line-hit / line-found ratio
#   complexity        — lizard (cross-language; per-function cyclomatic avg)
#   module_size       — lizard (average NLOC per function/file)
#   dependency_cycles — madge --circular (full import-graph cycle detection;
#                        richer than the C# adapter — TS has a first-class
#                        static import graph that madge can traverse without
#                        running the toolchain)

QM_TS_ADAPTER_DIR="${QM_TS_ADAPTER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Run coverage using vitest → LCOV.
# Falls back to 0 if vitest is not present or tests fail.
# Outputs: coverage:<percent>
qm_adapter_typescript_coverage() {
  local repo_root="${1:-$PWD}"

  if ! command -v node &>/dev/null; then
    echo "coverage:0"
    return 0
  fi

  local cov_dir; cov_dir="$(mktemp -d)"
  (
    cd "$repo_root"
    npx vitest run --coverage --coverage.provider=v8 \
      --coverage.reporter=lcov \
      --coverage.reportsDirectory="$cov_dir" \
      --reporter=silent 2>/dev/null || true
  )

  local lcov_file; lcov_file="$(find "$cov_dir" -name 'lcov.info' | head -1)"
  if [[ -f "$lcov_file" ]]; then
    local rate
    rate="$(awk '
      /^LH:/ { lh += substr($0,4) }
      /^LF:/ { lf += substr($0,4) }
      END { if (lf > 0) printf "%.1f", lh/lf*100; else print "0" }
    ' "$lcov_file")"
    echo "coverage:${rate:-0}"
  else
    echo "coverage:0"
  fi
  rm -rf "$cov_dir"
}

# Compute average cyclomatic complexity using lizard over .ts/.js files.
# Outputs: complexity:<avg_cyclomatic>
qm_adapter_typescript_complexity() {
  local repo_root="${1:-$PWD}"

  if ! command -v lizard &>/dev/null; then
    echo "complexity:0"
    return 0
  fi

  local complexity
  complexity="$(lizard "$repo_root" --languages javascript \
    --exclude "*/node_modules/*" --exclude "*/.next/*" \
    --exclude "*/dist/*" --exclude "*/build/*" \
    2>/dev/null | awk '/^Average cyclomatic/ {print $NF}' | head -1)"
  echo "complexity:${complexity:-0}"
}

# Compute average module size (NLOC) using lizard.
# Outputs: module_size:<avg_nloc>
qm_adapter_typescript_module_size() {
  local repo_root="${1:-$PWD}"

  if ! command -v lizard &>/dev/null; then
    echo "module_size:0"
    return 0
  fi

  local nloc
  nloc="$(lizard "$repo_root" --languages javascript \
    --exclude "*/node_modules/*" --exclude "*/.next/*" \
    --exclude "*/dist/*" --exclude "*/build/*" \
    2>/dev/null | awk '/^Average nloc/ {print $NF}' | head -1)"
  echo "module_size:${nloc:-0}"
}

# Detect import-graph cycles using madge --circular.
# madge traverses the full static import graph (including transitive deps
# across package boundaries if --include-npm is set; v1 uses in-repo only).
# Outputs: dependency_cycles:<count>
qm_adapter_typescript_deps() {
  local repo_root="${1:-$PWD}"

  if ! command -v node &>/dev/null; then
    echo "dependency_cycles:0"
    return 0
  fi

  # Find the entrypoint: index.ts > main.ts > src/ dir > repo root
  local entry
  entry="$(find "$repo_root" \
    \( -name 'index.ts' -o -name 'index.tsx' \) \
    -not -path '*/node_modules/*' | head -1)"
  [[ -z "$entry" ]] && entry="$(find "$repo_root" \
    \( -name 'main.ts' -o -name 'main.tsx' \) \
    -not -path '*/node_modules/*' | head -1)"
  [[ -z "$entry" ]] && entry="$repo_root/src"
  [[ -d "$entry" ]] || entry="$repo_root"

  local cycles
  cycles="$(
    cd "$repo_root"
    npx --yes madge --circular --extensions ts,tsx,js,jsx \
      --ignore-path .gitignore \
      "$entry" 2>/dev/null \
      | grep -c "→\|->" || echo 0
  )"
  echo "dependency_cycles:${cycles:-0}"
}

# Run all four TypeScript metrics and print one line per metric.
qm_adapter_typescript_run() {
  local repo_root="${1:-$PWD}"
  qm_adapter_typescript_coverage   "$repo_root"
  qm_adapter_typescript_complexity "$repo_root"
  qm_adapter_typescript_module_size "$repo_root"
  qm_adapter_typescript_deps       "$repo_root"
}
