#!/usr/bin/env bash
# cli/lib/setup-picker.sh — Single-screen setup picker (fzf or bash fallback).
# Exports: PICKER_BUNDLES (array), PICKER_HOOKS, PICKER_WORKFLOW,
#          PICKER_REVIEWERS, PICKER_MCP_ENABLED
# Sourced by cli/lib/setup.sh — never executed directly.

_PICKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PICKER_RELEASE_ROOT="$(cd "$_PICKER_DIR/../.." && pwd)"

# shellcheck source=./ui.sh
source "$_PICKER_DIR/ui.sh"

# Defaults (overwritten by run_picker)
PICKER_BUNDLES=("starter")
PICKER_HOOKS="true"
PICKER_WORKFLOW="true"
PICKER_REVIEWERS=""
PICKER_MCP_ENABLED="false"
PICKER_CUSTOMIZE="false"
PICKER_EXCLUDE=()

# ---------------------------------------------------------------------------
# fzf resolution: system fzf → bundled fzf → empty (bash fallback)
# ---------------------------------------------------------------------------
_picker_resolve_fzf() {
  if command -v fzf &>/dev/null; then
    echo "fzf"
    return
  fi
  local os arch bin
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  [[ "$arch" == "x86_64" ]] && arch="amd64"
  [[ "$arch" == "aarch64" || "$arch" == "arm64" ]] && arch="arm64"
  bin="$_PICKER_RELEASE_ROOT/bin/fzf/${os}-${arch}/fzf"
  if [[ -x "$bin" ]]; then
    echo "$bin"
    return
  fi
  echo ""
}

_PICKER_FZF="$(_picker_resolve_fzf)"

# ---------------------------------------------------------------------------
# Bundle auto-discovery — enumerate $RELEASE/bundles/*.yml in stable order
# (starter first, then alphabetical) so new bundles surface in the picker
# without code changes.
# ---------------------------------------------------------------------------
_PICKER_BUNDLES=()
_PICKER_BUNDLE_DESCS=()

_picker_load_bundles() {
  _PICKER_BUNDLES=()
  _PICKER_BUNDLE_DESCS=()
  local bundles_dir="$_PICKER_RELEASE_ROOT/bundles"
  [[ -d "$bundles_dir" ]] || return 0

  local ordered=()
  if [[ -f "$bundles_dir/starter.yml" ]]; then
    ordered+=("starter")
  fi
  local f name
  for f in "$bundles_dir"/*.yml; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .yml)"
    [[ "$name" == "starter" ]] && continue
    ordered+=("$name")
  done

  for name in "${ordered[@]}"; do
    f="$bundles_dir/$name.yml"
    local desc
    desc="$(grep -m1 '^description:' "$f" | sed 's/^description:[[:space:]]*//' | sed 's/^"//;s/"$//' || true)"
    _PICKER_BUNDLES+=("$name")
    _PICKER_BUNDLE_DESCS+=("${desc:-(no description)}")
  done
}

_picker_load_bundles

_PICKER_FEATURES=(hooks workflow reviewers mcp)
_PICKER_FEATURE_DESCS=(
  "destructive-guard, session-start"
  "pr-open, pr-merge, release"
  "→ prompted after install"
  "→ prompted after install"
)
# Built-in defaults — used only when manifest absent OR key missing.
_PICKER_FEATURE_DEFAULTS=(true true false false)

# ---------------------------------------------------------------------------
# Current state — read existing .octopus.yml so the picker reflects what's
# already in effect instead of opening with everything unchecked.
# ---------------------------------------------------------------------------
_CURRENT_BUNDLES=()
_CURRENT_HOOKS=""
_CURRENT_WORKFLOW=""
_CURRENT_MCP=""
_CURRENT_EXCLUDES=()

_picker_load_current_state() {
  _CURRENT_BUNDLES=()
  _CURRENT_HOOKS=""
  _CURRENT_WORKFLOW=""
  _CURRENT_MCP=""
  _CURRENT_EXCLUDES=()

  local manifest="${MANIFEST_PATH:-${PROJECT_ROOT:-$PWD}/.octopus.yml}"
  [[ -f "$manifest" ]] || return 0

  local in_bundles=0 in_mcp=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    # New top-level key resets list-tracking
    if [[ "$line" =~ ^[a-zA-Z] ]]; then
      in_bundles=0
      in_mcp=0
    fi
    if [[ "$line" =~ ^bundles:[[:space:]]*$ ]]; then
      in_bundles=1
      continue
    fi
    if [[ "$line" =~ ^mcp:[[:space:]]*$ ]]; then
      in_mcp=1
      continue
    fi
    if [[ $in_bundles -eq 1 && "$line" =~ ^[[:space:]]+-[[:space:]]*([a-zA-Z][a-zA-Z0-9_-]*) ]]; then
      _CURRENT_BUNDLES+=("${BASH_REMATCH[1]}")
      continue
    fi
    if [[ $in_mcp -eq 1 && "$line" =~ ^[[:space:]]+-[[:space:]]*([a-zA-Z][a-zA-Z0-9_-]*) ]]; then
      _CURRENT_MCP="true"
      continue
    fi
    if [[ "$line" =~ ^hooks:[[:space:]]*(true|false) ]]; then
      _CURRENT_HOOKS="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^workflow:[[:space:]]*(true|false) ]]; then
      _CURRENT_WORKFLOW="${BASH_REMATCH[1]}"
    fi
  done < "$manifest"

  # RM-139: pre-check auto-detected / --stack profiles (stack-*/db-*) even on a
  # fresh repo, so the picker opens with the detected stack/DB already selected.
  # The user's final toggles stay authoritative (unchecking removes it).
  local _p
  for _p in ${SETUP_PROFILES:-}; do
    _picker_array_contains "$_p" "${_CURRENT_BUNDLES[@]}" || _CURRENT_BUNDLES+=("$_p")
  done

  # Members already excluded in the manifest start unchecked in the tree.
  local _e
  while IFS= read -r _e; do
    [[ -n "$_e" ]] && _CURRENT_EXCLUDES+=("$_e")
  done < <(_picker_current_excludes)
}

_picker_array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

_picker_effective_default() {
  # Args: feature_name index_in_defaults_array
  local fname="$1" idx="$2"
  case "$fname" in
    hooks)    [[ -n "$_CURRENT_HOOKS"    ]] && { echo "$_CURRENT_HOOKS";    return; } ;;
    workflow) [[ -n "$_CURRENT_WORKFLOW" ]] && { echo "$_CURRENT_WORKFLOW"; return; } ;;
    mcp)      [[ -n "$_CURRENT_MCP"      ]] && { echo "$_CURRENT_MCP";      return; } ;;
  esac
  echo "${_PICKER_FEATURE_DEFAULTS[$idx]}"
}

# ---------------------------------------------------------------------------
# Tree helpers (consumed by _picker_bundle_rows / _picker_member_rows)
# ---------------------------------------------------------------------------

# Emit a bundle's members as `name<TAB>kind` (skill|role|rule), in file order.
_picker_bundle_members() {
  local f="$_PICKER_RELEASE_ROOT/bundles/$1.yml" in_list="" line name
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      skills:*) in_list="skill" ;;
      roles:*)  in_list="role" ;;
      rules:*)  in_list="rule" ;;
      mcp:*|hooks:*|name:*|category:*|description:*|persona_*) in_list="" ;;
      [[:space:]]*-*)
        [[ -n "$in_list" ]] || continue
        name="${line#*- }"; name="${name%%#*}"; name="${name//[[:space:]]/}"
        [[ -z "$name" || "$name" == "[]" ]] && continue
        printf '%s\t%s\n' "$name" "$in_list"
        ;;
    esac
  done < "$f"
}

# The bundle's `category:` value (foundation|intent|stack|db|…), empty if none.
_picker_bundle_category() {
  local f="$_PICKER_RELEASE_ROOT/bundles/$1.yml"
  [[ -f "$f" ]] || return 0
  grep -m1 '^category:' "$f" 2>/dev/null \
    | sed 's/^category:[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//'
}

# Excludes already recorded in the manifest (so re-running preserves them).
_picker_current_excludes() {
  local manifest="${MANIFEST_PATH:-${PROJECT_ROOT:-$PWD}/.octopus.yml}" in=0 line
  [[ -f "$manifest" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[a-zA-Z] ]] && in=0
    if [[ "$line" =~ ^exclude:[[:space:]]*$ ]]; then in=1; continue; fi
    if [[ $in -eq 1 && "$line" =~ ^[[:space:]]+-[[:space:]]*([a-zA-Z][a-zA-Z0-9_-]*) ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
    fi
  done < "$manifest"
}

# Screen-1 rows — features + bundles grouped by category, NO members. Emits
#   id <TAB> visible <TAB> default(0|1) <TAB> desc
# id ∈ h:<cat> | f:<name> | b:<name>. default=1 = pre-selected (features on,
# current bundles). Pure / testable — no fzf, no temp files.
_picker_bundle_rows() {
  local i fname d
  printf 'h:Features\t  ── Features ──\t0\t\n'
  for (( i=0; i<${#_PICKER_FEATURES[@]}; i++ )); do
    fname="${_PICKER_FEATURES[$i]}"
    d=0; [[ "$(_picker_effective_default "$fname" "$i")" == "true" ]] && d=1
    printf 'f:%s\t  %s\t%s\t%s\n' "$fname" "$fname" "$d" "${_PICKER_FEATURE_DESCS[$i]}"
  done

  # Bundle categories in display order, then an "Other" catch-all so no bundle
  # is dropped if it carries an unrecognized category.
  local cats=("foundation:Foundation" "intent:Intent" "stack:Stack" "db:Database")
  local written=" " pair key disp name desc selflag wrote_head
  for pair in "${cats[@]}" "*:Other"; do
    key="${pair%%:*}"; disp="${pair#*:}"; wrote_head=""
    for (( i=0; i<${#_PICKER_BUNDLES[@]}; i++ )); do
      name="${_PICKER_BUNDLES[$i]}"
      case "$written" in *" $name "*) continue ;; esac
      if [[ "$key" != "*" ]]; then
        [[ "$(_picker_bundle_category "$name")" == "$key" ]] || continue
      fi
      [[ -z "$wrote_head" ]] && { printf 'h:%s\t  ── %s ──\t0\t\n' "$disp" "$disp"; wrote_head=1; }
      desc="${_PICKER_BUNDLE_DESCS[$i]}"
      selflag=0
      _picker_array_contains "$name" "${_CURRENT_BUNDLES[@]}" && selflag=1
      printf 'b:%s\t %s\t%s\t%s\n' "$name" "$name" "$selflag" "$desc"
      written+="$name "
    done
  done
}

# Screen-2 rows — for each given bundle that has members, a header + its members
# (default checked unless already in _CURRENT_EXCLUDES). Same 4 columns. Pure /
# testable. Empty output when no given bundle has members.
_picker_member_rows() {
  local name mname mkind mdef first
  for name in "$@"; do
    first=1
    while IFS=$'\t' read -r mname mkind; do
      [[ -n "$mname" ]] || continue
      [[ -n "$first" ]] && { printf 'h:%s\t  ── %s ──\t0\t\n' "$name" "$name"; first=""; }
      mdef=1
      _picker_array_contains "$mname" "${_CURRENT_EXCLUDES[@]}" && mdef=0
      printf 'm:%s\t      %s (%s)\t%s\t%s\n' \
        "$mname" "$mname" "$mkind" "$mdef" "$mkind in the $name bundle"
    done < <(_picker_bundle_members "$name")
  done
}

# Pure: echo the union members (file $1, one per line) absent from the kept set
# (file $2). Used to turn "what stayed checked" into the manifest exclude:.
_picker_diff_union_kept() {
  local union_f="$1" kept_f="$2" m
  while IFS= read -r m; do
    [[ -n "$m" ]] || continue
    grep -qxF -- "$m" "$kept_f" 2>/dev/null || printf '%s\n' "$m"
  done < "$union_f"
}

# ---------------------------------------------------------------------------
# One fzf screen, native multi-select. Reads rows (id<TAB>vis<TAB>def<TAB>desc)
# on stdin; pre-selects def=1 rows via load/pos/toggle; guards category headers
# (the `──` rows) from being marked. Echoes the marked ids (field 1), one per
# line. Exit status: 0 confirm (ENTER), 1 cancel (Ctrl-C), 2 back (ESC — only
# when $4 "back" is set; otherwise ESC cancels). No reload/execute/state.
# ---------------------------------------------------------------------------
_picker_fzf_screen() {
  local fzf_bin="$1" prompt="$2" header="$3" back="${4:-}"
  local tmp; tmp="$(mktemp -d)"
  local input="" loadbind="" n=0 id vis def desc
  : > "$tmp/desc"
  while IFS=$'\t' read -r id vis def desc; do
    [[ -z "$id" ]] && continue
    n=$((n + 1))
    input+="$id"$'\t'"$vis"$'\n'
    printf '%s\t%s\n' "$id" "$desc" >> "$tmp/desc"
    [[ "$def" == "1" ]] && loadbind+="pos($n)+toggle+"
  done
  loadbind="${loadbind%+}"

  # Preview wrapper — best-effort (selection never depends on it). Takes the
  # whole line ({}) and extracts the id, so it's immune to --with-nth/{1}.
  local prev="$tmp/desc.sh"
  cat > "$prev" <<'PREV'
#!/usr/bin/env bash
line="$1"; id="${line%%$'\t'*}"
awk -F'\t' -v id="$id" '$1==id{sub(/^[^\t]*\t/,""); print; exit}' "$QM_DESC"
PREV
  chmod +x "$prev"

  local args=(
    --multi --no-sort --layout=reverse --height=~85% --border=rounded
    --delimiter=$'\t' --with-nth=2 --nth=2
    --prompt="$prompt" --pointer="▶" --marker="✓" --header="$header"
    --preview="QM_DESC=$tmp/desc $prev {}" --preview-window='right,42%,wrap'
    # Header rows (the `──` separators) must not be selectable.
    --bind='space:transform:[[ {} == *──* ]] && echo ignore || echo toggle'
    --bind='tab:transform:[[ {} == *──* ]] && echo down || echo toggle+down'
    --bind='btab:transform:[[ {} == *──* ]] && echo up || echo toggle+up'
  )
  # Pre-selection runs pos()+toggle for each default row; without a final
  # `first` the cursor is left on the last toggled row (bottom of the list).
  [[ -n "$loadbind" ]] && args+=(--bind="load:${loadbind}+first")
  # Back step: explicitly rebind ESC to emit a sentinel and accept (overrides
  # ESC's default `abort` reliably, unlike --expect). Ctrl-C still aborts.
  [[ -n "$back" ]] && args+=(--bind='esc:print(__BACK__)+accept')

  local out rc
  # set -e-safe: capture rc in an if-condition so a non-zero fzf exit (Ctrl-C)
  # doesn't abort the whole `octopus setup` (cli/octopus.sh runs set -euo).
  if out="$(printf '%s' "$input" | "$fzf_bin" "${args[@]}" 2>/dev/tty)"; then rc=0; else rc=$?; fi
  rm -rf "$tmp"
  [[ $rc -ne 0 ]] && return 1   # Ctrl-C / no-match → cancel
  # ESC (back) printed the sentinel as the first output line.
  [[ -n "$back" && "$(printf '%s' "$out" | head -1)" == "__BACK__" ]] && return 2
  printf '%s' "$out" | cut -f1
}

# ---------------------------------------------------------------------------
# Two-screen fzf picker: (1) choose bundles + features, (2) fine-tune the
# members of the chosen bundles. Each screen is a flat, coherent native
# multi-select — no parent/child live coupling, hence no inverted state and no
# reload/execute. Screen 2 is skipped when no chosen bundle has members.
# ---------------------------------------------------------------------------
_picker_run_fzf() {
  local fzf_bin="$1"
  _picker_load_current_state

  local id rc kept memrows
  while :; do
    # --- Screen 1: bundles + features -------------------------------------
    # Pre-selection reflects _CURRENT_* — updated below so ESC-back re-opens
    # screen 1 with the choices the user already made, not the original state.
    local sel1
    sel1="$(_picker_bundle_rows | _picker_fzf_screen "$fzf_bin" \
      "  Octopus Setup › bundles  " \
      "  SPACE select · ENTER → next · Ctrl-C cancel")" \
      || { ui_warn "Setup cancelled."; exit 0; }

    PICKER_BUNDLES=()
    PICKER_HOOKS="false"; PICKER_WORKFLOW="false"; PICKER_REVIEWERS=""
    PICKER_MCP_ENABLED="false"; PICKER_CUSTOMIZE="false"
    while IFS= read -r id; do
      case "$id" in
        b:*)         PICKER_BUNDLES+=("${id#b:}") ;;
        f:hooks)     PICKER_HOOKS="true" ;;
        f:workflow)  PICKER_WORKFLOW="true" ;;
        f:reviewers) PICKER_REVIEWERS="__ask__" ;;
        f:mcp)       PICKER_MCP_ENABLED="true" ;;
      esac
    done <<< "$sel1"
    [[ ${#PICKER_BUNDLES[@]} -eq 0 ]] && PICKER_BUNDLES=("starter")

    # Carry the screen-1 choices into the pre-selection state, so going back
    # from screen 2 returns here with them intact.
    _CURRENT_BUNDLES=("${PICKER_BUNDLES[@]}")
    _CURRENT_HOOKS="$PICKER_HOOKS"; _CURRENT_WORKFLOW="$PICKER_WORKFLOW"
    _CURRENT_MCP="$PICKER_MCP_ENABLED"

    # --- Screen 2: fine-tune members of the chosen bundles ----------------
    PICKER_EXCLUDE=()
    memrows="$(_picker_member_rows "${PICKER_BUNDLES[@]}")"
    [[ -z "$memrows" ]] && break   # no members to tune → done

    # set -e-safe rc capture: ESC returns 2 (back); without the if-guard, set -e
    # would abort `octopus setup` on that non-zero before the case runs — which
    # is exactly why ESC appeared to "abandon" setup.
    if kept="$(printf '%s\n' "$memrows" | _picker_fzf_screen "$fzf_bin" \
      "  Fine-tune members ›  " \
      "  uncheck to EXCLUDE · ENTER confirm · ESC ← back · Ctrl-C cancel" \
      back)"; then rc=0; else rc=$?; fi
    case "$rc" in
      2) continue ;;                                  # ESC → back to screen 1
      0) ;;                                           # ENTER → compute excludes
      *) ui_warn "Setup cancelled."; exit 0 ;;        # Ctrl-C → cancel
    esac

    local tmp2; tmp2="$(mktemp -d)"
    printf '%s\n' "$kept" | sed -n 's/^m://p' | sort -u > "$tmp2/kept"
    _picker_member_union "${PICKER_BUNDLES[@]}" > "$tmp2/union"
    local ex
    while IFS= read -r ex; do
      [[ -n "$ex" ]] && PICKER_EXCLUDE+=("$ex")
    done < <(_picker_diff_union_kept "$tmp2/union" "$tmp2/kept")
    rm -rf "$tmp2"
    break
  done
}

# Shallow union of the skills + roles + rules listed across the given bundle
# ymls (de-duplicated, stable order). Rules are included so a stack/db profile's
# rule (e.g. `typescript`) is deselectable too — `_apply_excludes` already drops
# from OCTOPUS_RULES. Pure/testable — no fzf, no globals consumed.
_picker_member_union() {
  local b f line in_list seen=" " name
  for b in "$@"; do
    f="$_PICKER_RELEASE_ROOT/bundles/$b.yml"
    [[ -f "$f" ]] || continue
    in_list=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        skills:*|roles:*|rules:*) in_list="yes" ;;
        mcp:*|hooks:*|name:*|category:*|description:*|persona_*) in_list="" ;;
        [[:space:]]*-*)
          [[ -n "$in_list" ]] || continue
          name="${line#*- }"; name="${name%%#*}"; name="${name//[[:space:]]/}"
          [[ -z "$name" || "$name" == "[]" ]] && continue
          case "$seen" in *" $name "*) ;; *) seen+="$name "; printf '%s\n' "$name" ;; esac
          ;;
      esac
    done < "$f"
  done
}

# Map a space/comma-separated list of 1-based indices to the union members they
# select (for exclusion). Out-of-range and non-numeric tokens are ignored.
# Pure/testable — no tty, no globals. Mirrors the bundle index parsing.
_picker_indices_to_members() {
  local raw="$1"; shift
  local -a union=("$@")
  local norm tok
  norm=$(printf '%s' "$raw" | tr ',\t' '  ' | tr -s ' ')
  for tok in $norm; do
    [[ "$tok" =~ ^[1-9][0-9]*$ ]] || continue
    (( tok >= 1 && tok <= ${#union[@]} )) || continue
    printf '%s\n' "${union[$((tok-1))]}"
  done
}

# Bash-fallback member-deselect: numbered union, the user enters the indices to
# EXCLUDE (default none → keep all). Sets PICKER_EXCLUDE. (The fzf path does this
# inline via the pre-expanded tree; this is the no-fzf equivalent.)
_picker_member_deselect_bash() {
  PICKER_EXCLUDE=()
  local -a _union=()
  while IFS= read -r m; do [[ -n "$m" ]] && _union+=("$m"); done \
    < <(_picker_member_union "${PICKER_BUNDLES[@]}")
  [[ ${#_union[@]} -eq 0 ]] && return 0

  echo ""
  echo "  Members from your bundles (all kept by default):"
  local i
  for (( i=0; i<${#_union[@]}; i++ )); do
    printf "    %2d. %s\n" "$((i+1))" "${_union[$i]}"
  done
  printf "  Numbers to EXCLUDE — space/comma-separated [none]: "
  local raw; read -r raw </dev/tty; raw="${raw:-}"
  while IFS= read -r m; do [[ -n "$m" ]] && PICKER_EXCLUDE+=("$m"); done \
    < <(_picker_indices_to_members "$raw" "${_union[@]}")
}

# ---------------------------------------------------------------------------
# Bash fallback — numbered list + read, with [*] markers for current state
# ---------------------------------------------------------------------------
_picker_run_bash() {
  _picker_load_current_state

  echo ""
  echo "  Available bundles (✓ = currently in .octopus.yml):"
  local i marker
  for (( i=0; i<${#_PICKER_BUNDLES[@]}; i++ )); do
    if _picker_array_contains "${_PICKER_BUNDLES[$i]}" "${_CURRENT_BUNDLES[@]}"; then
      marker="✓"
    else
      marker=" "
    fi
    printf "    %d. [%s] %-12s %s\n" "$((i+1))" "$marker" "${_PICKER_BUNDLES[$i]}" "${_PICKER_BUNDLE_DESCS[$i]}"
  done
  echo ""

  # Default for the input: numbers of currently-selected bundles, or "1" if none.
  local current_indices=()
  for (( i=0; i<${#_PICKER_BUNDLES[@]}; i++ )); do
    if _picker_array_contains "${_PICKER_BUNDLES[$i]}" "${_CURRENT_BUNDLES[@]}"; then
      current_indices+=("$((i+1))")
    fi
  done
  local default_input
  if [[ ${#current_indices[@]} -gt 0 ]]; then
    default_input="${current_indices[*]}"
  else
    default_input="1"
  fi

  PICKER_BUNDLES=()
  while true; do
    printf "  Bundle(s) — space or comma-separated [%s]: " "$default_input"
    local raw_choice
    read -r raw_choice </dev/tty
    raw_choice="${raw_choice:-$default_input}"
    local normalised
    normalised=$(printf '%s' "$raw_choice" | tr ',\t' '  ' | tr -s ' ')
    local invalid=() valid_picks=()
    local token
    for token in $normalised; do
      if [[ "$token" =~ ^[1-9][0-9]*$ ]] && (( token >= 1 && token <= ${#_PICKER_BUNDLES[@]} )); then
        valid_picks+=("${_PICKER_BUNDLES[$((token-1))]}")
      else
        invalid+=("$token")
      fi
    done
    if [[ ${#invalid[@]} -gt 0 ]]; then
      printf "  Invalid: %s — enter numbers 1–%d\n" "${invalid[*]}" "${#_PICKER_BUNDLES[@]}"
      continue
    fi
    if [[ ${#valid_picks[@]} -eq 0 ]]; then
      printf "  Enter at least one number.\n"
      continue
    fi
    PICKER_BUNDLES=("${valid_picks[@]}")
    break
  done

  # Feature defaults follow current state when present.
  local hooks_default workflow_default
  [[ "$_CURRENT_HOOKS" == "false" ]] && hooks_default="n" || hooks_default="y"
  [[ "$_CURRENT_WORKFLOW" == "false" ]] && workflow_default="n" || workflow_default="y"

  echo ""
  echo "  Features (Enter = keep current, y/n = change):"
  _picker_bash_yn "  Hooks (destructive-guard, session-start)" "$hooks_default" \
    && PICKER_HOOKS="true" || PICKER_HOOKS="false"
  _picker_bash_yn "  Workflow commands (pr-open, pr-merge, release)" "$workflow_default" \
    && PICKER_WORKFLOW="true" || PICKER_WORKFLOW="false"
  _picker_bash_yn "  Configure reviewers" "n" \
    && PICKER_REVIEWERS="__ask__" || PICKER_REVIEWERS=""
  _picker_bash_yn "  Configure MCP servers" "n" \
    && PICKER_MCP_ENABLED="true" || PICKER_MCP_ENABLED="false"

  # Granular member-deselect — parity with the fzf `customize` step.
  if _picker_bash_yn "  Customize (deselect individual skills/roles/rules)" "n"; then
    PICKER_CUSTOMIZE="true"
    _picker_member_deselect_bash
  fi
  echo ""
}

_picker_bash_yn() {
  local prompt="$1" default="$2"
  local hint
  [[ "$default" == "y" ]] && hint="[Y/n]" || hint="[y/N]"
  printf "%s %s " "$prompt" "$hint"
  local reply
  read -r reply </dev/tty
  reply="${reply:-$default}"
  [[ "${reply,,}" == "y" ]]
}

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------
run_picker() {
  if [[ -n "$_PICKER_FZF" ]]; then
    _picker_run_fzf "$_PICKER_FZF"
  else
    _picker_run_bash
  fi
}
