#!/usr/bin/env bash
# cli/lib/adapter-csharp.sh — C# code-metrics adapter (RM-147).
#
# Implements the stack-agnostic metric contract for C#/.NET repos.
# Called by cli/lib/code-metrics.sh when stack=csharp.
#
# Output contract: one line per metric, format:
#   <metric_name>:<numeric_value>
#
# Tool pinning (v1):
#   coverage       — dotnet-coverage (binary instrumentation) → Cobertura XML,
#                    root line-rate; falls back to coverlet XPlat collector when
#                    dotnet-coverage is not installed. Honours optional config
#                    code_metrics.coverage.{test_filter,settings}.
#   complexity     — lizard (cross-language; per-function cyclomatic avg)
#   module_size    — lizard (average NLOC per function/file)
#   dependency_cycles — dotnet list reference + Python DFS cycle detector
#                       (project-to-project cycles only; no NuGet-graph cycles
#                        in v1 — no free madge equivalent for C# assembly graphs)

CM_ADAPTER_DIR="${CM_ADAPTER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Directories that must never count toward repo metrics: build output, vendored
# deps, and Claude Code agent worktrees (.claude/worktrees holds full repo copies
# that would otherwise double-count files and let `find ... | head -1` pick a
# stale copy). Used by every find/lizard call below.
CM_CS_PRUNE_FIND=(-not -path '*/obj/*' -not -path '*/bin/*' -not -path '*/.claude/*' -not -path '*/node_modules/*')
CM_CS_PRUNE_LIZARD=(--exclude '*/obj/*' --exclude '*/bin/*' --exclude '*/.claude/*' --exclude '*/node_modules/*')

# Run coverage measurement → Cobertura XML.
# Prefers dotnet-coverage (binary instrumentation; much faster than coverlet's
# XPlat collector on large/async-heavy codebases). Falls back to the coverlet
# XPlat collector when dotnet-coverage is absent. Reads optional config
# code_metrics.coverage.test_filter (dotnet test --filter) and .settings
# (dotnet-coverage settings file). Outputs: coverage:<percent>
cm_adapter_csharp_coverage() {
  local repo_root="${1:-$PWD}"

  # Find a test project. Prefer a *.Tests.csproj / *Test.csproj — running
  # `dotnet test` on a non-test project yields no coverage, so picking the
  # first csproj on disk (alphabetical/traversal order) was unreliable.
  local test_proj
  test_proj="$(find "$repo_root" -name '*.csproj' "${CM_CS_PRUNE_FIND[@]}" \
    | grep -iE '[._-]tests?\.csproj$' | head -1)"
  if [[ -z "$test_proj" ]]; then
    test_proj="$(find "$repo_root" -name '*.csproj' "${CM_CS_PRUNE_FIND[@]}" | head -1)"
  fi
  if [[ -z "$test_proj" ]]; then
    echo "coverage:0"
    return 0
  fi

  # Optional string config (e.g. monorepos / fast unit-only coverage):
  #   code_metrics.coverage.test_filter — appended as `dotnet test --filter`
  #   code_metrics.coverage.settings    — dotnet-coverage settings file (path
  #                                           absolute, or relative to repo root)
  local test_filter settings_path
  test_filter="$(cm_field_str coverage test_filter 2>/dev/null || true)"
  settings_path="$(cm_field_str coverage settings 2>/dev/null || true)"

  # Security gate: test_filter is attacker-influenceable config that ends up in
  # the command string parsed by dotnet-coverage. Fail closed on anything outside
  # the filter grammar so a poisoned value cannot inject extra dotnet arguments.
  if [[ -n "$test_filter" ]] && ! cm_is_safe_filter "$test_filter"; then
    echo "cm_adapter_csharp_coverage: rejecting unsafe coverage.test_filter: $test_filter" >&2
    echo "coverage:0"
    return 0
  fi

  local cov_dir; cov_dir="$(mktemp -d)"
  local rate="0"

  if command -v dotnet-coverage &>/dev/null; then
    # Preferred: dotnet-coverage (binary instrumentation). coverlet's XPlat
    # collector can be pathologically slow on large/async-heavy codebases
    # (observed: a full suite that never finished in 10min vs ~40s here).
    # dotnet-coverage tokenises this command string itself (no shell); the
    # filter value is wrapped in quotes and was allowlisted by cm_is_safe_filter
    # above, so it stays a single --filter argument (no shell/arg injection).
    local inner="dotnet test \"$test_proj\" --no-build"
    [[ -n "$test_filter" ]] && inner="$inner --filter \"$test_filter\""
    local settings_args=()
    if [[ -n "$settings_path" ]]; then
      [[ "$settings_path" != /* ]] && settings_path="$repo_root/$settings_path"
      [[ -f "$settings_path" ]] && settings_args=(-s "$settings_path")
    fi
    local cov_file="$cov_dir/coverage.cobertura.xml"
    # Redirect stdout too: dotnet-coverage and the inner `dotnet test` print
    # progress to stdout, which would otherwise leak into this function's output
    # (the metric contract is a single `coverage:<n>` line). The report goes to
    # the -o file, so suppressing the console stream is safe.
    dotnet-coverage collect "${settings_args[@]}" -f cobertura -o "$cov_file" "$inner" \
      >/dev/null 2>&1 || true
    if [[ -f "$cov_file" ]]; then
      # dotnet-coverage cobertura: a single root <coverage line-rate="..."> over
      # all included modules — use it directly (covered/valid, not a package mean).
      rate="$(awk -F'"' '/<coverage /{for(i=1;i<=NF;i++) if($i ~ /line-rate=/){printf "%.1f", $(i+1)*100; exit}}' "$cov_file")"
    fi
  else
    # Fallback: coverlet XPlat collector → Cobertura (average of package line-rate).
    local filter_args=()
    [[ -n "$test_filter" ]] && filter_args=(--filter "$test_filter")
    # Suppress stdout+stderr: `dotnet test` prints progress to stdout, which
    # would leak into the metric output. Coverage is read from the results dir.
    dotnet test "$test_proj" --no-build "${filter_args[@]}" \
      --collect:"XPlat Code Coverage" \
      --results-directory "$cov_dir" \
      -- "DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura" \
      >/dev/null 2>&1 || true
    local cov_file; cov_file="$(find "$cov_dir" -name 'coverage.cobertura.xml' | head -1)"
    if [[ -f "$cov_file" ]]; then
      rate="$(awk -F'"' '
        /line-rate=/ && /<package / {sum += $2; n++}
        END { if (n > 0) printf "%.1f", sum/n*100; else print "0" }
      ' "$cov_file")"
    fi
  fi

  echo "coverage:${rate:-0}"
  rm -rf "$cov_dir"
}

# Run lizard to compute average cyclomatic complexity across all C# files.
# Outputs: complexity:<avg_cyclomatic>
cm_adapter_csharp_complexity() {
  local repo_root="${1:-$PWD}"

  if ! command -v lizard &>/dev/null; then
    echo "complexity:0"
    return 0
  fi

  # lizard's C# language id is "csharp" (not "cs" — that matches nothing).
  # The average lives in the tabular footer, not in an "Average ..." line:
  #   Total nloc | Avg.NLOC | AvgCCN | Avg.token | Fun Cnt | ...
  # The totals row is the only line with >=8 all-numeric fields; AvgCCN is $3.
  local complexity
  complexity="$(lizard "$repo_root" --languages csharp \
    "${CM_CS_PRUNE_LIZARD[@]}" 2>/dev/null \
    | awk 'NF>=8 && $1 ~ /^[0-9]+$/ && $NF ~ /^[0-9.]+$/ {v=$3} END{print (v==""?0:v)}')"
  echo "complexity:${complexity:-0}"
}

# Compute average module size (NLOC) using lizard.
# Outputs: module_size:<avg_nloc>
cm_adapter_csharp_module_size() {
  local repo_root="${1:-$PWD}"

  if ! command -v lizard &>/dev/null; then
    echo "module_size:0"
    return 0
  fi

  # See cm_adapter_csharp_complexity: "csharp" language id + tabular footer.
  # Avg.NLOC (average lines per function) is column $2 of the totals row.
  local nloc
  nloc="$(lizard "$repo_root" --languages csharp \
    "${CM_CS_PRUNE_LIZARD[@]}" 2>/dev/null \
    | awk 'NF>=8 && $1 ~ /^[0-9]+$/ && $NF ~ /^[0-9.]+$/ {v=$2} END{print (v==""?0:v)}')"
  echo "module_size:${nloc:-0}"
}

# Detect project-reference dependency cycles using dotnet list reference.
# Builds adjacency list from .csproj → .csproj references, then runs a DFS
# (Tarjan's SCC) to count SCCs with >1 node.
#
# Note: this covers project-level cycles only. NuGet package cycles are not
# detected in v1 — no free C# equivalent of madge for package graphs.
# Outputs: dependency_cycles:<count>
cm_adapter_csharp_deps() {
  local repo_root="${1:-$PWD}"

  if ! command -v dotnet &>/dev/null || ! command -v python3 &>/dev/null; then
    echo "dependency_cycles:0"
    return 0
  fi

  # Gather all .csproj paths
  local projs_file; projs_file="$(mktemp)"
  find "$repo_root" -name '*.csproj' "${CM_CS_PRUNE_FIND[@]}" \
    > "$projs_file" 2>/dev/null || true

  # Build reference map and detect cycles
  local cycles
  cycles="$(python3 - "$projs_file" <<'PYEOF'
import subprocess, sys, re, os

projs_file = sys.argv[1]
with open(projs_file) as f:
    projs = [l.strip() for l in f if l.strip()]

graph = {}
for p in projs:
    name = os.path.splitext(os.path.basename(p))[0]
    try:
        out = subprocess.check_output(
            ['dotnet', 'list', p, 'reference'],
            text=True, stderr=subprocess.DEVNULL)
        refs = re.findall(r'([A-Za-z0-9._-]+)\.csproj', out)
        # Drop self-edges: the "no Project to Project references in project
        # .../<name>.csproj" message makes the regex capture the project itself.
        graph[name] = [r for r in refs if r != name]
    except Exception:
        graph[name] = []

# Tarjan's SCC
index_counter = [0]
stack = []
lowlink = {}
index = {}
on_stack = {}
scc_cycles = [0]

def strongconnect(v):
    index[v] = index_counter[0]
    lowlink[v] = index_counter[0]
    index_counter[0] += 1
    stack.append(v)
    on_stack[v] = True
    for w in graph.get(v, []):
        if w not in index:
            strongconnect(w)
            lowlink[v] = min(lowlink[v], lowlink.get(w, lowlink[v]))
        elif on_stack.get(w):
            lowlink[v] = min(lowlink[v], index[w])
    if lowlink[v] == index[v]:
        scc = []
        while True:
            w = stack.pop()
            on_stack[w] = False
            scc.append(w)
            if w == v:
                break
        if len(scc) > 1:
            scc_cycles[0] += 1

for v in list(graph.keys()):
    if v not in index:
        strongconnect(v)

print(scc_cycles[0])
PYEOF
  2>/dev/null || echo 0)"

  rm -f "$projs_file"
  echo "dependency_cycles:${cycles:-0}"
}

# ---------------------------------------------------------------------------
# RM-148 v2 pack — debt markers + readability counters + doc coverage
# ---------------------------------------------------------------------------
# All deterministic grep/awk/lizard heuristics scoped to *.cs. Counters reuse
# the pure helpers in code-metrics-lib.sh; the adapter supplies C# patterns.

# Concatenate all C# source files to stdin (pruned), for the stdin-based helpers.
cm_cs_source_cat() {
  local repo_root="${1:-$PWD}"
  find "$repo_root" -name '*.cs' "${CM_CS_PRUNE_FIND[@]}" -print0 2>/dev/null \
    | xargs -0 cat 2>/dev/null
}

# Debt markers — counts of pending-work / obsolete / dead / suppression lines.
cm_adapter_csharp_todo_markers() {
  echo "todo_markers:$(cm_count_matches '(^|[^A-Za-z])(TODO|FIXME|HACK|XXX)([^A-Za-z]|:|$)' "${1:-$PWD}" --include='*.cs')"
}
cm_adapter_csharp_deprecations() {
  echo "deprecations:$(cm_count_matches '\[Obsolete' "${1:-$PWD}" --include='*.cs')"
}
cm_adapter_csharp_dead_code() {
  echo "dead_code:$(cm_count_matches '#if[[:space:]]+false|//[[:space:]]*dead([[:space:]]|$)' "${1:-$PWD}" --include='*.cs')"
}
cm_adapter_csharp_suppressions() {
  echo "suppressions:$(cm_count_matches '#pragma[[:space:]]+warning[[:space:]]+disable|\[SuppressMessage' "${1:-$PWD}" --include='*.cs')"
}

# Readability — deepest brace nesting and average parameter count.
cm_adapter_csharp_nesting_depth() {
  echo "nesting_depth:$(cm_cs_source_cat "${1:-$PWD}" | cm_max_nesting)"
}
cm_adapter_csharp_param_count() {
  local repo_root="${1:-$PWD}"
  if ! command -v lizard &>/dev/null; then echo "param_count:0"; return 0; fi
  # lizard per-function rows carry a `name@<start>-<end>@<file>` location; PARAM
  # is $4. The @start-end@ signature distinguishes function rows from the
  # file-summary / totals rows (which have no @range@).
  local avg
  avg="$(lizard "$repo_root" --languages csharp "${CM_CS_PRUNE_LIZARD[@]}" 2>/dev/null \
    | awk '/@[0-9]+-[0-9]+@/ { sum += $4; n++ } END { if (n>0) printf "%.1f", sum/n; else print 0 }')"
  echo "param_count:${avg:-0}"
}
cm_adapter_csharp_magic_numbers() {
  echo "magic_numbers:$(cm_cs_source_cat "${1:-$PWD}" | cm_magic_numbers)"
}

# lint_density — Roslyn build warnings per 1000 NLOC (best-effort; 0 if dotnet
# or lizard absent, or the build does not run).
cm_adapter_csharp_lint_density() {
  local repo_root="${1:-$PWD}"
  if ! command -v dotnet &>/dev/null || ! command -v lizard &>/dev/null; then
    echo "lint_density:0"; return 0
  fi
  local warnings nloc
  warnings="$( (cd "$repo_root" && dotnet build --no-restore 2>/dev/null) \
    | grep -cE ': warning ' || echo 0)"
  nloc="$(lizard "$repo_root" --languages csharp "${CM_CS_PRUNE_LIZARD[@]}" 2>/dev/null \
    | awk 'NF>=8 && $1 ~ /^[0-9]+$/ && $NF ~ /^[0-9.]+$/ {v=$1} END{print (v==""?0:v)}')"
  echo "lint_density:$(awk -v w="$warnings" -v n="$nloc" 'BEGIN{ if(n+0>0) printf "%.1f", w/n*1000; else print 0 }')"
}

# doc_coverage — public declarations carrying a /// doc comment on the line
# above (blank lines tolerated between). Heuristic over the concatenated source.
cm_adapter_csharp_doc_coverage() {
  local counts
  counts="$(cm_cs_source_cat "${1:-$PWD}" | awk '
    /^[[:space:]]*\/\/\//             { doced=1; next }
    /^[[:space:]]*public[[:space:]]/  { total++; if (doced) doc++; doced=0; next }
    /^[[:space:]]*$/                  { next }
    { doced=0 }
    END { print (doc+0) "|" (total+0) }
  ')"
  echo "doc_coverage:$(cm_doc_ratio "${counts%|*}" "${counts#*|}")"
}

# ---------------------------------------------------------------------------
# RM-149 — hotspots (churn × complexity). Decay metric: files that change a lot
# AND are complex. Needs git history (new capability vs the snapshot v1 metrics).
# Config: code_metrics.hotspots.{window_days(90),churn_min(20),ccn_min(10)}.
# ---------------------------------------------------------------------------
cm_adapter_csharp_hotspots() {
  local repo_root="${1:-$PWD}"
  if ! command -v git &>/dev/null || ! command -v lizard &>/dev/null; then
    echo "hotspots:0"; return 0
  fi
  local window churn_min ccn_min
  window="$(cm_field hotspots window_days 2>/dev/null || true)";  window="${window:-90}"
  churn_min="$(cm_field hotspots churn_min 2>/dev/null || true)"; churn_min="${churn_min:-20}"
  ccn_min="$(cm_field hotspots ccn_min 2>/dev/null || true)";     ccn_min="${ccn_min:-10}"

  local churn_f ccn_f; churn_f="$(mktemp)"; ccn_f="$(mktemp)"
  # Per-file churn over the window (repo-relative paths).
  ( cd "$repo_root" 2>/dev/null \
      && git log --since="${window} days ago" --numstat --format= -- '*.cs' 2>/dev/null ) \
    | cm_git_churn > "$churn_f"
  # Per-file max CCN from lizard (run relative so paths join with churn).
  ( cd "$repo_root" 2>/dev/null \
      && lizard . --languages csharp "${CM_CS_PRUNE_LIZARD[@]}" 2>/dev/null ) \
    | awk '/@[0-9]+-[0-9]+@/ { loc=$NF; sub(/.*@/,"",loc); sub(/^\.\//,"",loc);
                               if ($2+0 > m[loc]) m[loc]=$2 }
           END { for (f in m) printf "%d\t%s\n", m[f], f }' > "$ccn_f"

  echo "hotspots:$(cm_hotspot_count "$churn_min" "$ccn_min" "$churn_f" "$ccn_f")"
  rm -f "$churn_f" "$ccn_f"
}

# Run all C# metrics and print one line per metric.
cm_adapter_csharp_run() {
  local repo_root="${1:-$PWD}"
  # v1
  cm_adapter_csharp_coverage    "$repo_root"
  cm_adapter_csharp_complexity  "$repo_root"
  cm_adapter_csharp_module_size "$repo_root"
  cm_adapter_csharp_deps        "$repo_root"
  # v2 pack (RM-148)
  cm_adapter_csharp_todo_markers  "$repo_root"
  cm_adapter_csharp_deprecations  "$repo_root"
  cm_adapter_csharp_dead_code     "$repo_root"
  cm_adapter_csharp_suppressions  "$repo_root"
  cm_adapter_csharp_nesting_depth "$repo_root"
  cm_adapter_csharp_param_count   "$repo_root"
  cm_adapter_csharp_magic_numbers "$repo_root"
  cm_adapter_csharp_lint_density  "$repo_root"
  cm_adapter_csharp_doc_coverage  "$repo_root"
  # v3 (RM-149)
  cm_adapter_csharp_hotspots      "$repo_root"
}
