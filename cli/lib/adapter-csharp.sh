#!/usr/bin/env bash
# cli/lib/adapter-csharp.sh — C# quality-metrics adapter (RM-147).
#
# Implements the stack-agnostic metric contract for C#/.NET repos.
# Called by cli/lib/quality-metrics-cmd.sh when stack=csharp.
#
# Output contract: one line per metric, format:
#   <metric_name>:<numeric_value>
#
# Tool pinning (v1):
#   coverage       — coverlet.console → Cobertura XML → line-rate average
#   complexity     — lizard (cross-language; per-function cyclomatic avg)
#   module_size    — lizard (average NLOC per function/file)
#   dependency_cycles — dotnet list reference + Python DFS cycle detector
#                       (project-to-project cycles only; no NuGet-graph cycles
#                        in v1 — no free madge equivalent for C# assembly graphs)

QM_ADAPTER_DIR="${QM_ADAPTER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Run coverage measurement using coverlet → Cobertura XML.
# Requires: coverlet.console installed globally or per-project.
# Outputs: coverage:<percent>
qm_adapter_csharp_coverage() {
  local repo_root="${1:-$PWD}"

  # Find a test project. Prefer a *.Tests.csproj / *Test.csproj — running
  # `dotnet test` on a non-test project yields no coverage, so picking the
  # first csproj on disk (alphabetical/traversal order) was unreliable.
  local test_proj
  test_proj="$(find "$repo_root" -name '*.csproj' -not -path '*/obj/*' -not -path '*/bin/*' \
    | grep -iE '[._-]tests?\.csproj$' | head -1)"
  if [[ -z "$test_proj" ]]; then
    test_proj="$(find "$repo_root" -name '*.csproj' -not -path '*/obj/*' | head -1)"
  fi
  if [[ -z "$test_proj" ]]; then
    echo "coverage:0"
    return 0
  fi

  local cov_dir; cov_dir="$(mktemp -d)"
  dotnet test "$test_proj" --no-build \
    --collect:"XPlat Code Coverage" \
    --results-directory "$cov_dir" \
    -- "DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura" \
    2>/dev/null || true

  local cov_file; cov_file="$(find "$cov_dir" -name 'coverage.cobertura.xml' | head -1)"
  if [[ -f "$cov_file" ]]; then
    local rate
    rate="$(awk -F'"' '
      /line-rate=/ && /<package / {sum += $2; n++}
      END { if (n > 0) printf "%.1f", sum/n*100; else print "0" }
    ' "$cov_file")"
    echo "coverage:${rate:-0}"
  else
    echo "coverage:0"
  fi
  rm -rf "$cov_dir"
}

# Run lizard to compute average cyclomatic complexity across all C# files.
# Outputs: complexity:<avg_cyclomatic>
qm_adapter_csharp_complexity() {
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
    --exclude "*/obj/*" --exclude "*/bin/*" 2>/dev/null \
    | awk 'NF>=8 && $1 ~ /^[0-9]+$/ && $NF ~ /^[0-9.]+$/ {v=$3} END{print (v==""?0:v)}')"
  echo "complexity:${complexity:-0}"
}

# Compute average module size (NLOC) using lizard.
# Outputs: module_size:<avg_nloc>
qm_adapter_csharp_module_size() {
  local repo_root="${1:-$PWD}"

  if ! command -v lizard &>/dev/null; then
    echo "module_size:0"
    return 0
  fi

  # See qm_adapter_csharp_complexity: "csharp" language id + tabular footer.
  # Avg.NLOC (average lines per function) is column $2 of the totals row.
  local nloc
  nloc="$(lizard "$repo_root" --languages csharp \
    --exclude "*/obj/*" --exclude "*/bin/*" 2>/dev/null \
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
qm_adapter_csharp_deps() {
  local repo_root="${1:-$PWD}"

  if ! command -v dotnet &>/dev/null || ! command -v python3 &>/dev/null; then
    echo "dependency_cycles:0"
    return 0
  fi

  # Gather all .csproj paths
  local projs_file; projs_file="$(mktemp)"
  find "$repo_root" -name '*.csproj' -not -path '*/obj/*' -not -path '*/bin/*' \
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

# Run all four C# metrics and print one line per metric.
qm_adapter_csharp_run() {
  local repo_root="${1:-$PWD}"
  qm_adapter_csharp_coverage   "$repo_root"
  qm_adapter_csharp_complexity "$repo_root"
  qm_adapter_csharp_module_size "$repo_root"
  qm_adapter_csharp_deps       "$repo_root"
}
