#!/usr/bin/env bash
# cli/lib/knowledge-root.sh — knowledge-root registry loader (RM-106).
#
# Sourced by cli/lib/kr.sh. Parses the built-in defaults, resolves each root's
# path, and drops roots whose path is unset or absent. Override merging and the
# ADR-009 guard are layered on in later tasks.
#
# Engines (RM-107…109) never read these paths directly — only via `octopus kr`.

KR_LIB_DIR="${KR_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
KR_DEFAULTS="${KR_DEFAULTS:-$KR_LIB_DIR/knowledge-roots.default}"
# The repo where `octopus` was invoked; repo-relative roots resolve against it.
KR_PROJECT_ROOT="${KR_PROJECT_ROOT:-$PWD}"
# Override layers (ADR-009): project manifest, then user-scoped manifest.
KR_PROJECT_YML="${KR_PROJECT_YML:-$KR_PROJECT_ROOT/.octopus.yml}"
KR_USER_YML="${KR_USER_YML:-${XDG_CONFIG_HOME:-$HOME/.config}/octopus/.octopus.yml}"

# Column index of a field in the defaults / kr_load line (1-based).
kr_field_column() {
  case "$1" in
    id) echo 1;; path) echo 2;; link_convention) echo 3;; archive_dir) echo 4;;
    staleness_days) echo 5;; lens_profile) echo 6;; write_policy) echo 7;;
    *) echo 0;;
  esac
}

# Resolve a declared path to an absolute path, or empty if unresolvable.
#   $VAR        → value from user config (env for now); empty if unset
#   /abs        → as-is
#   repo/rel    → $KR_PROJECT_ROOT/repo/rel
kr_expand_path() {
  local p="$1"
  case "$p" in
    '$OCTOPUS_MEMORY_DIR')    printf '%s' "${OCTOPUS_MEMORY_DIR:-}" ;;
    '$CONSIGLIERE_WORKSPACE') printf '%s' "${CONSIGLIERE_WORKSPACE:-}" ;;
    /*)                       printf '%s' "$p" ;;
    *)                        printf '%s/%s' "$KR_PROJECT_ROOT" "$p" ;;
  esac
}

# Per-user roots: their path comes from user config ($VAR), so a path override
# in the *project* manifest would leak a private path into the team repo.
kr_per_user_ids() {
  awk -F'|' '/^[^#]/ && NF>=2 && $2 ~ /^\$/ {print $1}' "$KR_DEFAULTS"
}

# ADR-009 guard: fail if the project manifest sets `path:` for a per-user root.
# Scalar overrides (e.g. staleness_days) there are allowed.
kr_guard_project_overrides() {
  local id
  for id in $(kr_per_user_ids); do
    if [[ -n "$(kr_override "$KR_PROJECT_YML" "$id" path)" ]]; then
      echo "path override not allowed in project .octopus.yml: $id" >&2
      return 1
    fi
  done
}

# Emit one resolved line per present root:
#   id|abs_path|link_convention|archive_dir|staleness_days|lens_profile|write_policy
kr_load() {
  kr_guard_project_overrides || return 1
  awk -F'|' '/^[^#]/ && NF>=2' "$KR_DEFAULTS" \
  | while IFS='|' read -r id path conv archive days lens policy; do
      local resolved; resolved="$(kr_expand_path "$path")"
      [[ -n "$resolved" && -e "$resolved" ]] || continue
      printf '%s|%s|%s|%s|%s|%s|%s\n' \
        "$id" "$resolved" "$conv" "$archive" "$days" "$lens" "$policy"
    done
}

# Read a single shallow override from a .octopus.yml:
#   knowledge_roots:
#     <id>:
#       <field>: <value>
# Echoes the value, or nothing if the file/key is absent. Pure awk, 2-space YAML.
kr_override() {
  local file="$1" id="$2" field="$3"
  [[ -f "$file" ]] || return 0
  awk -v id="$id" -v field="$field" '
    /^[^ \t#]/ { in_kr = ($0 ~ /^knowledge_roots:[[:space:]]*$/); in_id = 0; next }
    in_kr && /^  [^ \t]/ {
      cur = $0; sub(/^  /, "", cur); sub(/:.*$/, "", cur); in_id = (cur == id); next
    }
    in_kr && in_id && /^    [^ \t]/ {
      key = $0; sub(/^    /, "", key); sub(/:.*$/, "", key)
      if (key == field) {
        val = $0; sub(/^[^:]*:[[:space:]]*/, "", val); sub(/[[:space:]]+$/, "", val)
        print val; exit
      }
    }
  ' "$file"
}

# Resolve a field for a present root: default < project override < user override.
# Empty if the root is not present in the registry.
# Capture kr_load fully before consuming it — piping into an early-exiting
# reader (grep -q / awk exit) under `set -o pipefail` SIGPIPEs the producer.
kr_field() {
  local id="$1" field="$2" col roots line val ov
  col="$(kr_field_column "$field")"; [[ "$col" -ne 0 ]] || return 0
  roots="$(kr_load)"
  line="$(awk -F'|' -v id="$id" '$1==id{print; exit}' <<<"$roots")"
  [[ -n "$line" ]] || return 0
  val="$(cut -d'|' -f"$col" <<<"$line")"
  ov="$(kr_override "$KR_PROJECT_YML" "$id" "$field")"; [[ -n "$ov" ]] && val="$ov"
  ov="$(kr_override "$KR_USER_YML"    "$id" "$field")"; [[ -n "$ov" ]] && val="$ov"
  printf '%s\n' "$val"
}
