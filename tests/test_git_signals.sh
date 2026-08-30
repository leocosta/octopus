#!/usr/bin/env bash
# tests/test_git_signals.sh — git-signals engine (RM-184).
# Co-change clustering, diff verdict, degradation, config, and the command
# entrypoint. Fixtures are real git repos: the signal IS history, so it cannot
# be faked with static files.
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

# shellcheck source=../cli/lib/git-signals-lib.sh
source "$OCTOPUS_DIR/cli/lib/git-signals-lib.sh"
# shellcheck source=../cli/lib/code-metrics-lib.sh
source "$OCTOPUS_DIR/cli/lib/code-metrics-lib.sh"

# `check` runs its command through `bash -c`, which starts a shell that does not
# inherit shell functions. Export them or every function-level check silently
# passes/fails on "command not found" instead of on behaviour.
export -f gs_churn gs_cochange gs_verdict gs_status gs_field_or gs_changed_paths

FIXTURES=()
trap 'rm -rf "${FIXTURES[@]}"' EXIT

# Create a git repo fixture. Echoes its path.
new_repo() {
  local d; d="$(mktemp -d)"; FIXTURES+=("$d")
  git -C "$d" init -q
  git -C "$d" config user.email t@example.com
  git -C "$d" config user.name Test
  git -C "$d" config commit.gpgsign false
  printf '%s\n' "$d"
}

# commit_files <repo> <msg> <path>...
commit_files() {
  local d="$1" msg="$2"; shift 2
  local p
  for p in "$@"; do
    mkdir -p "$d/$(dirname "$p")"
    printf 'line %s\n' "$RANDOM" >> "$d/$p"
    git -C "$d" add "$p"
  done
  git -C "$d" commit -q -m "$msg"
}

log_stream() { git -C "$1" log --format='C %H' --name-only; }

# ---------------------------------------------------------------------------
# SECTION 1 — gs_churn
# ---------------------------------------------------------------------------
echo "--- Section 1: churn ---"

R1="$(new_repo)"
for i in 1 2 3; do commit_files "$R1" "c$i" "a.ts"; done
commit_files "$R1" "b" "b.ts"

CHURN1="$(git -C "$R1" log --numstat --format= | gs_churn)"
check "churn: reports the busier path" \
  bash -c "echo '$CHURN1' | awk '\$2==\"a.ts\"{print \$1}' | grep -qE '^[0-9]+$'"
check "churn: a.ts outranks b.ts" bash -c "
  a=\$(echo '$CHURN1' | awk '\$2==\"a.ts\"{print \$1}')
  b=\$(echo '$CHURN1' | awk '\$2==\"b.ts\"{print \$1}')
  [ \"\$a\" -gt \"\$b\" ]"
check_not "churn: skips binary numstat rows" \
  bash -c "printf -- '-\t-\tbin.png\n' | gs_churn | grep -q bin.png"

# ---------------------------------------------------------------------------
# SECTION 2 — gs_cochange clustering
# ---------------------------------------------------------------------------
echo "--- Section 2: clustering ---"

# Three files that always move together, 8 times.
R2="$(new_repo)"
for i in $(seq 1 8); do
  commit_files "$R2" "together $i" \
    "payments/providers/index.ts" "payments/config/registry.ts" "payments/providers/boleto.ts"
done
CL2="$(log_stream "$R2" | gs_cochange 25 5 0.6 3)"

check "cluster: three co-changing files form one cluster" \
  bash -c "[ \"\$(echo '$CL2' | awk '{print \$1}' | sort -u | wc -l)\" -eq 1 ]"
check "cluster: has all three members" \
  bash -c "[ \"\$(echo '$CL2' | wc -l)\" -eq 3 ]"
check "cluster: support reflects the 8 shared commits" \
  bash -c "[ \"\$(echo '$CL2' | awk 'NR==1{print \$2}')\" -eq 8 ]"

# A changelog-style file touched on EVERY commit must not join the cluster:
# high support with everything, but low confidence against its own count.
R3="$(new_repo)"
for i in $(seq 1 8); do
  commit_files "$R3" "together $i" "core/a.ts" "core/b.ts" "core/c.ts" "CHANGELOG.md"
done
for i in $(seq 1 30); do commit_files "$R3" "solo $i" "CHANGELOG.md"; done
CL3="$(log_stream "$R3" | gs_cochange 25 5 0.6 3)"
check_not "cluster: a file changed on every commit is excluded by cohesion" \
  bash -c "echo '$CL3' | grep -q CHANGELOG.md"
check "cluster: the genuine trio still survives" \
  bash -c "[ \"\$(echo '$CL3' | wc -l)\" -eq 3 ]"

# A mass commit must not manufacture a cluster.
R4="$(new_repo)"
WIDE=(); for i in $(seq 1 40); do WIDE+=("wide/f$i.ts"); done
for i in $(seq 1 8); do commit_files "$R4" "mass $i" "${WIDE[@]}"; done
CL4="$(log_stream "$R4" | gs_cochange 25 5 0.6 3)"
check "cluster: commits wider than max_files_per_commit are dropped" \
  bash -c "[ -z \"\$(echo -n '$CL4')\" ]"

# Below min_support there is no cluster.
R5="$(new_repo)"
for i in 1 2; do commit_files "$R5" "pair $i" "x/a.ts" "x/b.ts" "x/c.ts"; done
CL5="$(log_stream "$R5" | gs_cochange 25 5 0.6 3)"
check "cluster: below min_support nothing survives" \
  bash -c "[ -z \"\$(echo -n '$CL5')\" ]"

# min_cluster excludes a mere pair.
R6="$(new_repo)"
for i in $(seq 1 8); do commit_files "$R6" "pair $i" "y/a.ts" "y/b.ts"; done
CL6="$(log_stream "$R6" | gs_cochange 25 5 0.6 3)"
check "cluster: a pair does not reach min_cluster of 3" \
  bash -c "[ -z \"\$(echo -n '$CL6')\" ]"

# ---------------------------------------------------------------------------
# SECTION 3 — gs_verdict
# ---------------------------------------------------------------------------
echo "--- Section 3: verdict ---"

CLF="$(mktemp)"; FIXTURES+=("$CLF")
printf '1\t8\t0.80\tpayments/providers/index.ts\n1\t8\t0.80\tpayments/config/registry.ts\n1\t8\t0.80\tpayments/providers/boleto.ts\n' > "$CLF"
CHF="$(mktemp)"; FIXTURES+=("$CHF")

printf 'payments/providers/index.ts\n' > "$CHF"
check "verdict: touching one member does not enlarge" \
  bash -c "gs_verdict '$CLF' '$CHF' 1 | grep -q 'false$'"

printf 'payments/providers/index.ts\npayments/config/registry.ts\n' > "$CHF"
check "verdict: touching two members with no outsider does not enlarge" \
  bash -c "gs_verdict '$CLF' '$CHF' 1 | grep -q 'false$'"

printf 'payments/providers/index.ts\npayments/config/registry.ts\npayments/providers/pix.ts\n' > "$CHF"
check "verdict: two members plus a new path enlarges" \
  bash -c "gs_verdict '$CLF' '$CHF' 1 | grep -q 'true$'"
check "verdict: counts two touched members and one outsider" \
  bash -c "gs_verdict '$CLF' '$CHF' 1 | grep -qP '^2\t1\t'"

printf 'unrelated/z.ts\n' > "$CHF"
check "verdict: an unrelated diff does not enlarge" \
  bash -c "gs_verdict '$CLF' '$CHF' 1 | grep -q 'false$'"

# ---------------------------------------------------------------------------
# SECTION 4 — degradation (absence of evidence is never zero)
# ---------------------------------------------------------------------------
echo "--- Section 4: degradation ---"

R7="$(new_repo)"
for i in $(seq 1 8); do commit_files "$R7" "c $i" "a.ts" "b.ts" "c.ts"; done
check "status: a healthy repo reports ok" \
  bash -c "[ \"\$(gs_status '$R7' 90 5)\" = ok ]"

NOREPO="$(mktemp -d)"; FIXTURES+=("$NOREPO")
check "status: a non-repo reports not-a-repo" \
  bash -c "gs_status '$NOREPO' 90 5 | grep -q 'unavailable:not-a-repo'"

R8="$(new_repo)"
commit_files "$R8" "only one" "a.ts"
check "status: too few commits in the window reports empty-window" \
  bash -c "gs_status '$R8' 90 5 | grep -q 'unavailable:empty-window'"

SHALLOW="$(mktemp -d)"; FIXTURES+=("$SHALLOW")
git clone -q --depth 1 "file://$R7" "$SHALLOW/clone" 2>/dev/null
check "status: a shallow clone reports shallow-clone" \
  bash -c "gs_status '$SHALLOW/clone' 90 5 | grep -q 'unavailable:shallow-clone'"

# ---------------------------------------------------------------------------
# SECTION 5 — config resolution through CM_CONFIG_ROOT
# ---------------------------------------------------------------------------
echo "--- Section 5: config ---"

YML="$(mktemp -d)"; FIXTURES+=("$YML")
cat > "$YML/.octopus.yml" <<'YAMLEOF'
git_signals:
  cochange:
    window_days: 30
    min_support: 9
code_metrics:
  coverage:
    min: 80
YAMLEOF

check "config: git_signals block is read" bash -c "
  CM_PROJECT_YML='$YML/.octopus.yml' CM_PERSONAL_YML=/nonexistent \
    bash -c 'source $OCTOPUS_DIR/cli/lib/code-metrics-lib.sh
             source $OCTOPUS_DIR/cli/lib/git-signals-lib.sh
             [ \"\$(gs_field_or cochange window_days 90)\" = 30 ]'"
check "config: an unset field falls back to the default" bash -c "
  CM_PROJECT_YML='$YML/.octopus.yml' CM_PERSONAL_YML=/nonexistent \
    bash -c 'source $OCTOPUS_DIR/cli/lib/code-metrics-lib.sh
             source $OCTOPUS_DIR/cli/lib/git-signals-lib.sh
             [ \"\$(gs_field_or cochange min_cluster 3)\" = 3 ]'"
check "config: code_metrics block still resolves (no cross-talk)" bash -c "
  CM_PROJECT_YML='$YML/.octopus.yml' CM_PERSONAL_YML=/nonexistent \
    bash -c 'source $OCTOPUS_DIR/cli/lib/code-metrics-lib.sh
             [ \"\$(cm_field_or coverage min 0)\" = 80 ]'"
check "config: git_signals does not leak into code_metrics" bash -c "
  CM_PROJECT_YML='$YML/.octopus.yml' CM_PERSONAL_YML=/nonexistent \
    bash -c 'source $OCTOPUS_DIR/cli/lib/code-metrics-lib.sh
             [ \"\$(cm_field_or cochange window_days 90)\" = 90 ]'"

BADYML="$(mktemp -d)"; FIXTURES+=("$BADYML")
cat > "$BADYML/.octopus.yml" <<'YAMLEOF'
git_signals:
  cochange:
    min_support: 5; system("touch /tmp/pwned")
YAMLEOF
check "config: a non-numeric value is rejected by the numeric guard" bash -c "
  CM_PROJECT_YML='$BADYML/.octopus.yml' CM_PERSONAL_YML=/nonexistent \
    bash -c 'source $OCTOPUS_DIR/cli/lib/code-metrics-lib.sh
             source $OCTOPUS_DIR/cli/lib/git-signals-lib.sh
             [ \"\$(gs_field_or cochange min_support 5)\" = 5 ]'"

# ---------------------------------------------------------------------------
# SECTION 6 — command entrypoint
# ---------------------------------------------------------------------------
echo "--- Section 6: entrypoint ---"

check "cli: git-signals is registered as a command" \
  grep -q '^git-signals|' "$OCTOPUS_DIR/cli/lib/commands.default"

R9="$(new_repo)"
for i in $(seq 1 8); do
  commit_files "$R9" "together $i" "svc/index.ts" "svc/registry.ts" "svc/boleto.ts"
done
OUT9="$(cd "$R9" && bash "$OCTOPUS_DIR/cli/octopus.sh" git-signals 2>&1)"
check "cli: prints the report header" bash -c "echo '$OUT9' | grep -q '=== git-signals ==='"
check "cli: reports status ok" bash -c "echo '$OUT9' | grep -q '^status: ok'"
check "cli: prints a cluster with its members" bash -c "echo '$OUT9' | grep -q 'svc/registry.ts'"
check "cli: prints churn per member" bash -c "echo '$OUT9' | grep -qE 'member: .* churn:[0-9]+'"

OUT10="$(cd "$NOREPO" && bash "$OCTOPUS_DIR/cli/octopus.sh" git-signals 2>&1)"
check "cli: a non-repo reports unavailable" \
  bash -c "echo '$OUT10' | grep -q 'status: unavailable:not-a-repo'"
check_not "cli: unavailable prints no cluster line" \
  bash -c "echo '$OUT10' | grep -q '^cluster:'"

# Ranking / ceiling: two qualifying clusters, only the enlarging one is shown.
R11="$(new_repo)"
for i in $(seq 1 8); do commit_files "$R11" "alpha $i" "alpha/a.ts" "alpha/b.ts" "alpha/c.ts"; done
for i in $(seq 1 8); do commit_files "$R11" "beta $i" "beta/a.ts" "beta/b.ts" "beta/c.ts"; done
git -C "$R11" checkout -q -b feat/x
mkdir -p "$R11/beta"; printf 'x\n' > "$R11/beta/d.ts"
printf 'x\n' >> "$R11/beta/a.ts"; printf 'x\n' >> "$R11/beta/b.ts"
git -C "$R11" add -A; git -C "$R11" commit -q -m "extend beta"
OUT11="$(cd "$R11" && bash "$OCTOPUS_DIR/cli/octopus.sh" git-signals --base HEAD~1 --ref HEAD 2>&1)"
check "cli: default ceiling prints exactly one cluster" \
  bash -c "[ \"\$(echo '$OUT11' | grep -c '^cluster:')\" -eq 1 ]"
check "cli: the enlarging cluster is the one reported" \
  bash -c "echo '$OUT11' | grep -q 'enlarges:true'"
check "cli: the outsider path is named" \
  bash -c "echo '$OUT11' | grep -q 'outsider: beta/d.ts'"

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
