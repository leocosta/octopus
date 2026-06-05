#!/usr/bin/env bash
# cli/lib/setup-picker-op.sh — pure state engine for the collapsible tree picker.
#
# No side effects on source: only functions. The interactive front-end
# (setup-picker.sh) writes a state directory, then fzf key-binds call back into
# `op_main <statedir> <cmd> [id]` to render / toggle / expand / describe. Keeping
# the logic here (file-only, no fzf, no globals) makes the tree unit-testable:
# write a catalog + state files, drive op_main, assert the rendered frames.
#
# State directory layout (all newline-delimited sets except catalog):
#   catalog  — ordered rows: kind<TAB>id<TAB>label<TAB>desc
#              kind ∈ head|feat|bundle|member ; id ∈ h:<cat>|f:<n>|b:<n>|m:<n>
#   sel      — selected bundle names
#   feat     — enabled feature names
#   excl     — excluded member names (a member is "kept" unless listed here)
#   exp      — expanded bundle names
#
# Rows are pre-ordered by the writer (category by category), so op_render just
# walks the catalog — no category logic lives here.

# --- set helpers (newline file as a set) -----------------------------------
_op_has()    { [[ -f "$1" ]] && grep -qxF -- "$2" "$1"; }
_op_add()    { _op_has "$1" "$2" || printf '%s\n' "$2" >> "$1"; }
_op_remove() {
  [[ -f "$1" ]] || return 0
  local tmp="$1.tmp"
  grep -vxF -- "$2" "$1" > "$tmp" 2>/dev/null || : > "$tmp"
  mv "$tmp" "$1"
}
_op_toggle() { if _op_has "$1" "$2"; then _op_remove "$1" "$2"; else _op_add "$1" "$2"; fi; }

# --- render: walk catalog → `id<TAB>visible` lines --------------------------
# Glyphs: checked [✓] / unchecked [ ]; bundles show ▸ collapsed / ▾ expanded.
# Members render only under an expanded bundle.
op_render() {
  local sd="$1"
  local kind id label desc name box twist parent mkind
  while IFS=$'\t' read -r kind id label desc || [[ -n "$kind" ]]; do
    [[ -z "$kind" ]] && continue
    name="${id#*:}"
    case "$kind" in
      head)
        printf '%s\t  ── %s ──\n' "$id" "$label" ;;
      feat)
        if _op_has "$sd/feat" "$name"; then box="✓"; else box=" "; fi
        printf '%s\t  [%s] %s\n' "$id" "$box" "$label" ;;
      bundle)
        if _op_has "$sd/sel" "$name"; then box="✓"; else box=" "; fi
        if _op_has "$sd/exp" "$name"; then twist="▾"; else twist="▸"; fi
        printf '%s\t [%s] %s %s\n' "$id" "$box" "$twist" "$label" ;;
      member)
        # desc field carries "<parent-bundle>|<kind>"
        parent="${desc%%|*}"; mkind="${desc#*|}"
        _op_has "$sd/exp" "$parent" || continue
        if _op_has "$sd/excl" "$name"; then box=" "; else box="✓"; fi
        printf '%s\t       [%s] %s (%s)\n' "$id" "$box" "$label" "$mkind" ;;
    esac
  done < "$sd/catalog"
}

# --- toggle the check-state of the row identified by <id> -------------------
op_toggle() {
  local sd="$1" id="$2" pfx="${2%%:*}" name="${2#*:}"
  case "$pfx" in
    b) _op_toggle "$sd/sel"  "$name" ;;
    m) _op_toggle "$sd/excl" "$name" ;;   # present in excl == unchecked
    f) _op_toggle "$sd/feat" "$name" ;;
    h) : ;;                               # category header — not selectable
  esac
}

# --- expand/collapse a bundle row ------------------------------------------
op_expand() {
  local sd="$1" pfx="${2%%:*}" name="${2#*:}"
  [[ "$pfx" == "b" ]] && _op_toggle "$sd/exp" "$name"
  return 0
}

# --- preview text for the row (description) ---------------------------------
op_describe() {
  local sd="$1" id="$2" kind c_id label desc
  while IFS=$'\t' read -r kind c_id label desc || [[ -n "$kind" ]]; do
    [[ "$c_id" == "$id" ]] || continue
    case "$kind" in
      member) printf '%s\n\n(%s)\n' "$label" "${desc#*|}" ;;
      *)      printf '%s\n\n%s\n' "$label" "$desc" ;;
    esac
    return 0
  done < "$sd/catalog"
}

# --- dispatch (called by the fzf wrapper script) ---------------------------
op_main() {
  local sd="$1" cmd="$2"; shift 2 || true
  case "$cmd" in
    render)   op_render   "$sd" ;;
    toggle)   op_toggle   "$sd" "$1" ;;
    expand)   op_expand   "$sd" "$1" ;;
    describe) op_describe "$sd" "$1" ;;
  esac
}
