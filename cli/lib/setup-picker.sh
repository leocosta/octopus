#!/usr/bin/env bash
# cli/lib/setup-picker.sh — Single-screen setup picker (fzf or bash fallback).
# Exports: PICKER_BUNDLES (array), PICKER_HOOKS, PICKER_WORKFLOW,
#          PICKER_REVIEWERS, PICKER_MCP_ENABLED
# Sourced by cli/lib/setup.sh — never executed directly.

_PICKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PICKER_RELEASE_ROOT="$(cd "$_PICKER_DIR/../.." && pwd)"

# shellcheck source=./ui.sh
source "$_PICKER_DIR/ui.sh"
# shellcheck source=./setup-picker-op.sh
source "$_PICKER_DIR/setup-picker-op.sh"

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

_picker_load_current_state() {
  _CURRENT_BUNDLES=()
  _CURRENT_HOOKS=""
  _CURRENT_WORKFLOW=""
  _CURRENT_MCP=""

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
# Catalog helpers for the collapsible tree (consumed by setup-picker-op.sh)
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

# Write the ordered catalog + initial state files into $1 (the state dir).
# Catalog rows: kind<TAB>id<TAB>label<TAB>desc — grouped by category so the
# engine (setup-picker-op.sh) only has to walk it in order.
_picker_write_catalog() {
  local sd="$1"
  : > "$sd/catalog"; : > "$sd/sel"; : > "$sd/feat"; : > "$sd/excl"; : > "$sd/exp"

  # Features block
  printf 'head\th:Features\tFeatures\t\n' >> "$sd/catalog"
  local i fname
  for (( i=0; i<${#_PICKER_FEATURES[@]}; i++ )); do
    fname="${_PICKER_FEATURES[$i]}"
    printf 'feat\tf:%s\t%s\t%s\n' "$fname" "$fname" "${_PICKER_FEATURE_DESCS[$i]}" >> "$sd/catalog"
    [[ "$(_picker_effective_default "$fname" "$i")" == "true" ]] && _op_add "$sd/feat" "$fname"
  done

  # Bundle categories in display order, then an "Other" catch-all so no bundle
  # is ever dropped if it carries an unrecognized category.
  local cats=("foundation:Foundation" "intent:Intent" "stack:Stack" "db:Database")
  local written=" " pair key disp name desc wrote_head mname mkind
  for pair in "${cats[@]}" "*:Other"; do
    key="${pair%%:*}"; disp="${pair#*:}"; wrote_head=""
    for (( i=0; i<${#_PICKER_BUNDLES[@]}; i++ )); do
      name="${_PICKER_BUNDLES[$i]}"
      case "$written" in *" $name "*) continue ;; esac
      if [[ "$key" == "*" ]]; then
        : # Other: accept whatever's left
      else
        [[ "$(_picker_bundle_category "$name")" == "$key" ]] || continue
      fi
      if [[ -z "$wrote_head" ]]; then
        printf 'head\th:%s\t%s\t\n' "$disp" "$disp" >> "$sd/catalog"; wrote_head=1
      fi
      desc="${_PICKER_BUNDLE_DESCS[$i]}"
      printf 'bundle\tb:%s\t%s\t%s\n' "$name" "$name" "$desc" >> "$sd/catalog"
      while IFS=$'\t' read -r mname mkind; do
        [[ -n "$mname" ]] || continue
        printf 'member\tm:%s\t%s\t%s|%s\n' "$mname" "$mname" "$name" "$mkind" >> "$sd/catalog"
      done < <(_picker_bundle_members "$name")
      written+="$name "
    done
  done

  # Initial selection mirrors the current manifest (+ detected profiles).
  local b
  if [[ ${#_CURRENT_BUNDLES[@]} -gt 0 ]]; then
    for b in "${_CURRENT_BUNDLES[@]}"; do _op_add "$sd/sel" "$b"; done
  fi
  [[ -s "$sd/sel" ]] || _op_add "$sd/sel" "starter"
  _picker_current_excludes >> "$sd/excl"
}

# ---------------------------------------------------------------------------
# fzf picker — collapsible tree (bundles expand into their skills/roles/rules)
# State lives in a temp dir; key-binds call back into setup-picker-op.sh via a
# generated wrapper, and `reload` re-renders after every toggle/expand.
# ---------------------------------------------------------------------------
_picker_run_fzf() {
  local fzf_bin="$1"
  _picker_load_current_state

  local sd; sd="$(mktemp -d)"
  _picker_write_catalog "$sd"

  # Wrapper the fzf binds invoke (execute runs in a fresh shell, so the state
  # dir + op-lib path are baked in here).
  local wrap="$sd/wrap"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'source %q\n' "$_PICKER_DIR/setup-picker-op.sh"
    printf 'op_main %q "$@"\n' "$sd"
  } > "$wrap"
  chmod +x "$wrap"

  local header="  SPACE toggle · → expand · ← collapse · TAB toggle+down · ENTER confirm · Ctrl-C cancel"
  "$wrap" render | "$fzf_bin" \
    --no-sort --layout=reverse --height=~85% --border=rounded \
    --delimiter=$'\t' --with-nth=2 --nth=2 \
    --prompt="  Octopus Setup › " --pointer="▶" \
    --header="$header" \
    --preview="$wrap describe {1}" --preview-window='right,42%,wrap' \
    --bind="space:execute-silent($wrap toggle {1})+reload($wrap render)" \
    --bind="right:execute-silent($wrap expand {1})+reload($wrap render)" \
    --bind="left:execute-silent($wrap expand {1})+reload($wrap render)" \
    --bind="tab:execute-silent($wrap toggle {1})+reload($wrap render)+down" \
    >/dev/null 2>/dev/tty || { ui_warn "Setup cancelled."; rm -rf "$sd"; exit 0; }

  # Read results back from the state dir.
  PICKER_BUNDLES=()
  local b
  while IFS= read -r b; do [[ -n "$b" ]] && PICKER_BUNDLES+=("$b"); done < "$sd/sel"
  [[ ${#PICKER_BUNDLES[@]} -eq 0 ]] && PICKER_BUNDLES=("starter")

  PICKER_HOOKS="false"; PICKER_WORKFLOW="false"; PICKER_REVIEWERS=""
  PICKER_MCP_ENABLED="false"; PICKER_CUSTOMIZE="false"
  local fnm
  while IFS= read -r fnm; do
    case "$fnm" in
      hooks)     PICKER_HOOKS="true" ;;
      workflow)  PICKER_WORKFLOW="true" ;;
      reviewers) PICKER_REVIEWERS="__ask__" ;;
      mcp)       PICKER_MCP_ENABLED="true" ;;
    esac
  done < "$sd/feat"

  # exclude = unchecked members that belong to a selected bundle.
  PICKER_EXCLUDE=()
  local -a _union=()
  while IFS= read -r m; do [[ -n "$m" ]] && _union+=("$m"); done \
    < <(_picker_member_union "${PICKER_BUNDLES[@]}")
  if [[ ${#_union[@]} -gt 0 ]]; then
    local e
    while IFS= read -r e; do
      [[ -n "$e" ]] || continue
      _picker_array_contains "$e" "${_union[@]}" && PICKER_EXCLUDE+=("$e")
    done < "$sd/excl"
  fi

  rm -rf "$sd"
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
# inline via the collapsible tree; this is the no-fzf equivalent.)
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
