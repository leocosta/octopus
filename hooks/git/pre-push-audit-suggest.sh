#!/usr/bin/env bash
# hooks/git/pre-push-audit-suggest.sh
# Advisory pre-push hook: suggests relevant Octopus audit skills based on diff.
# Never blocks the push. Never runs audits. Never touches the network.
set -uo pipefail

# Step 1: opt-out via env var.
if [[ -n "${OCTOPUS_SKIP_AUDIT_HOOK:-}" ]]; then
  exit 0
fi

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OCTOPUS_DIR="$(cd "$HOOK_DIR/../.." && pwd)"
AUDIT_MAP_LIB="$OCTOPUS_DIR/cli/lib/audit-map.sh"

if [[ ! -f "$AUDIT_MAP_LIB" ]]; then
  exit 0
fi

export AUDIT_MAP_OCTOPUS_DIR="$OCTOPUS_DIR"
# shellcheck source=../../cli/lib/audit-map.sh
source "$AUDIT_MAP_LIB"

# Step 2: compute diff range from stdin (git passes ref pairs).
range=""
while IFS=' ' read -r local_ref local_sha remote_ref remote_sha; do
  [[ -z "$local_sha" ]] && continue
  # All-zeros remote_sha means this is a new branch push.
  if [[ "$remote_sha" =~ ^0+$ ]]; then
    range="main..${local_sha}"
  else
    range="${remote_sha}..${local_sha}"
  fi
  break
done

if [[ -z "$range" ]]; then
  exit 0
fi

# Step 3: build diff and pipe into audit_map_all.
diff_file="$(mktemp)"
trap 'rm -f "$diff_file"' EXIT

git diff "$range" > "$diff_file" 2>/dev/null || true

if [[ ! -s "$diff_file" ]]; then
  exit 0
fi

# Step 4: collect matched audit names.
mapfile -t matched < <(audit_map_all "$diff_file")

if [[ ${#matched[@]} -eq 0 ]]; then
  exit 0
fi

# Step 5: print advisory blocklet.
_box_width=62
_border="$(printf '─%.0s' $(seq 1 $_box_width))"

printf "┌─ Octopus — audit suggestions %s┐\n" "$_border" \
  | head -c $(( _box_width + 4 ))
printf "\n"
printf "│ This push touches code typically audited by:%-15s│\n" ""
for name in "${matched[@]}"; do
  printf "│   • /octopus:%-45s│\n" "${name}"
done
printf "│ Run them in your agent before merging if applicable.%-8s│\n" ""
printf "│ Skip: OCTOPUS_SKIP_AUDIT_HOOK=1 git push%-20s│\n" ""
printf "└%s┘\n" "$_border"

# Step 6: exit 0 — never block the push.
exit 0
