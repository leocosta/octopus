#!/usr/bin/env bash
# hooks/git/pre-push-audit-suggest.sh
# Advisory pre-push hook: suggests relevant Octopus audit skills based on diff.
# Never blocks the push. Never dispatches an audit. Never touches the network.
#
# It runs BOTH deterministic stages before suggesting anything (RM-179):
#   1. audit-map    — is this audit a candidate? (path tokens OR content regex)
#   2. audit-prepass — does it have anything to look at? (file_patterns AND
#                      line_patterns), the same resolver `codereview` Phase 2
#                      obeys when it decides whether to spawn a sub-agent.
# Reporting stage one as a conclusion is what made this hook suggest an audit
# that `octopus audit-scope` then reported as `skip`. Both stages are greps over
# a diff this hook already has — no model, no network.
set -uo pipefail

# Step 1: opt-out via env var.
if [[ -n "${OCTOPUS_SKIP_AUDIT_HOOK:-}" ]]; then
  exit 0
fi

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OCTOPUS_DIR="$(cd "$HOOK_DIR/../.." && pwd)"
AUDIT_MAP_LIB="$OCTOPUS_DIR/cli/lib/audit-map.sh"
AUDIT_PREPASS_LIB="$OCTOPUS_DIR/cli/lib/audit-prepass.sh"

if [[ ! -f "$AUDIT_MAP_LIB" ]]; then
  exit 0
fi

export AUDIT_MAP_OCTOPUS_DIR="$OCTOPUS_DIR"
# shellcheck source=../../cli/lib/audit-map.sh
source "$AUDIT_MAP_LIB"

# The second stage is optional: an older install may not carry it, and a hook
# that dies because a library moved is a hook that blocks pushes.
HAVE_PREPASS=0
if [[ -f "$AUDIT_PREPASS_LIB" ]]; then
  export AUDIT_PREPASS_OCTOPUS_DIR="$OCTOPUS_DIR"
  # shellcheck source=../../cli/lib/audit-prepass.sh
  source "$AUDIT_PREPASS_LIB" && HAVE_PREPASS=1
fi

# Step 2: resolve base and ref from stdin (git passes ref pairs). Kept as two
# values rather than one range string — the second stage takes refs.
base=""
ref=""
while IFS=' ' read -r local_ref local_sha remote_ref remote_sha; do
  [[ -z "$local_sha" ]] && continue
  # All-zeros remote_sha means this is a new branch push.
  if [[ "$remote_sha" =~ ^0+$ ]]; then
    base="main"
  else
    base="$remote_sha"
  fi
  ref="$local_sha"
  break
done

if [[ -z "$ref" || -z "$base" ]]; then
  exit 0
fi

# Step 3: build diff.
diff_file="$(mktemp)"
trap 'rm -f "$diff_file"' EXIT

git diff "${base}..${ref}" > "$diff_file" 2>/dev/null || true

if [[ ! -s "$diff_file" ]]; then
  exit 0
fi

# Step 4: stage one — collect candidate audits.
#
# Read into the array with a plain loop, not `mapfile`: that is a bash 4.0
# builtin, and on a shell without it `matched` stayed unset, so `${#matched[@]}`
# under `set -u` aborted the hook with a non-zero status — which git reads as
# "reject the push". A hook documented as never blocking must not have a bash
# version that blocks.
matched=()
while IFS= read -r _name; do
  [[ -n "$_name" ]] && matched+=("$_name")
done < <(audit_map_all "$diff_file")

if [[ ${#matched[@]} -eq 0 ]]; then
  exit 0
fi

# Step 5: stage two — keep only the audits that actually have candidate files.
suggested=()
for name in "${matched[@]}"; do
  if [[ $HAVE_PREPASS -eq 0 ]]; then
    suggested+=("$name")
    continue
  fi

  count="$(audit_prepass_candidates "$name" "$base" "$ref" 2>/dev/null | grep -c '[^[:space:]]')"
  [[ "$count" =~ ^[0-9]+$ ]] || count=0

  # A candidate with nothing to look at is exactly what `audit-scope` reports as
  # `skip`, and suggesting it spends the reader's attention for nothing.
  if [[ "$count" -gt 0 ]]; then
    suggested+=("${name} (${count} file$([[ "$count" -eq 1 ]] || echo s))")
  fi
done

if [[ ${#suggested[@]} -eq 0 ]]; then
  exit 0
fi

# Step 6: print advisory blocklet.
_box_width=62
_border="$(printf '─%.0s' $(seq 1 $_box_width))"

printf "┌─ Octopus — audit suggestions %s┐\n" "$_border" \
  | head -c $(( _box_width + 4 ))
printf "\n"
printf "│ This push changes code these audits would look at:%-9s│\n" ""
for entry in "${suggested[@]}"; do
  printf "│   • /octopus:%-45s│\n" "${entry}"
done
printf "│ Run them in your agent before merging if applicable.%-8s│\n" ""
printf "│ Skip: OCTOPUS_SKIP_AUDIT_HOOK=1 git push%-20s│\n" ""
printf "└%s┘\n" "$_border"

# Step 7: exit 0 — never block the push.
exit 0
