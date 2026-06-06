#!/usr/bin/env bash
# cli/lib/adapter-typescript.sh — TypeScript code-metrics adapter (RM-147).
#
# Implements the stack-agnostic metric contract for TypeScript/JavaScript repos.
# Called by cli/lib/code-metrics.sh when stack=typescript.
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

CM_TS_ADAPTER_DIR="${CM_TS_ADAPTER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Run coverage using vitest → LCOV.
# Falls back to 0 if vitest is not present or tests fail.
# Outputs: coverage:<percent>
cm_adapter_typescript_coverage() {
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
cm_adapter_typescript_complexity() {
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
cm_adapter_typescript_module_size() {
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
cm_adapter_typescript_deps() {
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
      | grep -c "→\|->" || true
  )"
  # grep -c already prints "0" on no match (and exits 1); `|| true` swallows the
  # exit without echoing a second "0" (which used to leak a stray line).
  echo "dependency_cycles:${cycles:-0}"
}

# ---------------------------------------------------------------------------
# RM-148 v2 pack — debt markers + readability counters + doc coverage
# ---------------------------------------------------------------------------
# Deterministic grep/awk/lizard heuristics scoped to .ts/.tsx/.js/.jsx. Counters
# reuse the pure helpers in code-metrics-lib.sh; the adapter supplies TS patterns.

CM_TS_INCLUDE=(--include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx')

# Concatenate all TS/JS source to stdin (pruned), for the stdin-based helpers.
cm_ts_source_cat() {
  local repo_root="${1:-$PWD}"
  find "$repo_root" \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) \
    -not -path '*/node_modules/*' -not -path '*/.next/*' \
    -not -path '*/dist/*' -not -path '*/build/*' -print0 2>/dev/null \
    | xargs -0 cat 2>/dev/null
}

# Debt markers.
cm_adapter_typescript_todo_markers() {
  echo "todo_markers:$(cm_count_matches '(^|[^A-Za-z])(TODO|FIXME|HACK|XXX)([^A-Za-z]|:|$)' "${1:-$PWD}" "${CM_TS_INCLUDE[@]}")"
}
cm_adapter_typescript_deprecations() {
  echo "deprecations:$(cm_count_matches '@deprecated' "${1:-$PWD}" "${CM_TS_INCLUDE[@]}")"
}
cm_adapter_typescript_dead_code() {
  echo "dead_code:$(cm_count_matches '//[[:space:]]*dead([[:space:]]|$)|eslint-disable.*no-unused' "${1:-$PWD}" "${CM_TS_INCLUDE[@]}")"
}
cm_adapter_typescript_suppressions() {
  echo "suppressions:$(cm_count_matches 'eslint-disable|@ts-ignore|@ts-nocheck' "${1:-$PWD}" "${CM_TS_INCLUDE[@]}")"
}

# Readability.
cm_adapter_typescript_nesting_depth() {
  echo "nesting_depth:$(cm_ts_source_cat "${1:-$PWD}" | cm_max_nesting)"
}
cm_adapter_typescript_param_count() {
  local repo_root="${1:-$PWD}"
  if ! command -v lizard &>/dev/null; then echo "param_count:0"; return 0; fi
  # lizard per-function rows carry a `name@<start>-<end>@<file>` location; PARAM
  # is $4. The @start-end@ signature distinguishes function rows from the
  # file-summary / totals rows.
  # Cover both .js and .ts: lizard treats TypeScript as a distinct language, so
  # `--languages javascript` alone analyses 0 files in a .ts-only repo.
  local avg
  avg="$(lizard "$repo_root" --languages javascript --languages typescript \
    --exclude "*/node_modules/*" --exclude "*/.next/*" \
    --exclude "*/dist/*" --exclude "*/build/*" 2>/dev/null \
    | awk '/@[0-9]+-[0-9]+@/ { sum += $4; n++ } END { if (n>0) printf "%.1f", sum/n; else print 0 }')"
  echo "param_count:${avg:-0}"
}
cm_adapter_typescript_magic_numbers() {
  echo "magic_numbers:$(cm_ts_source_cat "${1:-$PWD}" | cm_magic_numbers)"
}

# lint_density — eslint findings per 1000 NLOC (best-effort; 0 if node/eslint
# or lizard absent, or eslint is not configured).
cm_adapter_typescript_lint_density() {
  local repo_root="${1:-$PWD}"
  if ! command -v node &>/dev/null || ! command -v lizard &>/dev/null; then
    echo "lint_density:0"; return 0
  fi
  local findings nloc
  findings="$( (cd "$repo_root" && npx --no-install eslint . --format unix 2>/dev/null) \
    | grep -cE ': (warning|error)' || echo 0)"
  nloc="$(lizard "$repo_root" --languages javascript --languages typescript \
    --exclude "*/node_modules/*" --exclude "*/.next/*" \
    --exclude "*/dist/*" --exclude "*/build/*" 2>/dev/null \
    | awk '/@[0-9]+-[0-9]+@/ { sum += $1 } END { print sum + 0 }')"
  echo "lint_density:$(awk -v w="$findings" -v n="$nloc" 'BEGIN{ if(n+0>0) printf "%.1f", w/n*1000; else print 0 }')"
}

# doc_coverage — exported declarations carrying a /** … */ JSDoc above (blank
# lines tolerated). Heuristic over the concatenated source.
cm_adapter_typescript_doc_coverage() {
  local counts
  counts="$(cm_ts_source_cat "${1:-$PWD}" | awk '
    /\*\//                              { doced=1; next }
    /^[[:space:]]*export[[:space:]]/    { total++; if (doced) doc++; doced=0; next }
    /^[[:space:]]*$/                    { next }
    { doced=0 }
    END { print (doc+0) "|" (total+0) }
  ')"
  echo "doc_coverage:$(cm_doc_ratio "${counts%|*}" "${counts#*|}")"
}

# ---------------------------------------------------------------------------
# RM-149 — hotspots (churn × complexity). See the C# adapter for the rationale.
# Config: code_metrics.hotspots.{window_days(90),churn_min(20),ccn_min(10)}.
# ---------------------------------------------------------------------------
cm_adapter_typescript_hotspots() {
  local repo_root="${1:-$PWD}"
  if ! command -v git &>/dev/null || ! command -v lizard &>/dev/null; then
    echo "hotspots:0"; return 0
  fi
  local window churn_min ccn_min
  window="$(cm_field_or hotspots window_days 90)"
  churn_min="$(cm_field_or hotspots churn_min 20)"
  ccn_min="$(cm_field_or hotspots ccn_min 10)"

  local churn_f ccn_f; churn_f="$(mktemp)"; ccn_f="$(mktemp)"
  ( cd "$repo_root" 2>/dev/null \
      && git log --since="${window} days ago" --numstat --format= \
           -- '*.ts' '*.tsx' '*.js' '*.jsx' 2>/dev/null ) \
    | cm_git_churn > "$churn_f"
  ( cd "$repo_root" 2>/dev/null \
      && lizard . --languages javascript --languages typescript \
           --exclude "*/node_modules/*" --exclude "*/.next/*" \
           --exclude "*/dist/*" --exclude "*/build/*" 2>/dev/null ) \
    | awk '/@[0-9]+-[0-9]+@/ { loc=$NF; sub(/.*@/,"",loc); sub(/^\.\//,"",loc);
                               if ($2+0 > m[loc]) m[loc]=$2 }
           END { for (f in m) printf "%d\t%s\n", m[f], f }' > "$ccn_f"

  echo "hotspots:$(cm_hotspot_count "$churn_min" "$ccn_min" "$churn_f" "$ccn_f")"
  rm -f "$churn_f" "$ccn_f"
}

# ---------------------------------------------------------------------------
# RM-150 — perf_risk (info-only). See the C# adapter for the rationale.
# ---------------------------------------------------------------------------
cm_adapter_typescript_perf_risk() {
  # POSIX ERE, backslash-free (cm_perf_scan reads via ENVIRON; gawk mangles \b/\s/\.).
  local loopre='(^|[^A-Za-z])(for|while)([^A-Za-z]|$)|[.](forEach|map|filter|reduce)[[:space:]]*[(]'
  local riskre='await|fetch[(]|[.](find|findOne|aggregate|query)[(]|new [A-Z]'
  echo "perf_risk:$(cm_ts_source_cat "${1:-$PWD}" | cm_perf_scan "$loopre" "$riskre")"
}

# Run all TypeScript metrics and print one line per metric.
cm_adapter_typescript_run() {
  local repo_root="${1:-$PWD}"
  # v1
  cm_adapter_typescript_coverage    "$repo_root"
  cm_adapter_typescript_complexity  "$repo_root"
  cm_adapter_typescript_module_size "$repo_root"
  cm_adapter_typescript_deps        "$repo_root"
  # v2 pack (RM-148)
  cm_adapter_typescript_todo_markers  "$repo_root"
  cm_adapter_typescript_deprecations  "$repo_root"
  cm_adapter_typescript_dead_code     "$repo_root"
  cm_adapter_typescript_suppressions  "$repo_root"
  cm_adapter_typescript_nesting_depth "$repo_root"
  cm_adapter_typescript_param_count   "$repo_root"
  cm_adapter_typescript_magic_numbers "$repo_root"
  cm_adapter_typescript_lint_density  "$repo_root"
  cm_adapter_typescript_doc_coverage  "$repo_root"
  # v3 (RM-149)
  cm_adapter_typescript_hotspots      "$repo_root"
  # v3 (RM-150) — info-only
  cm_adapter_typescript_perf_risk     "$repo_root"
}
