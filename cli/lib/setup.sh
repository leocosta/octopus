# cli/lib/setup.sh — Configure Octopus in the current repository or at user scope.
# Sourced by bin/octopus. Variable $CLI_DIR must be set by caller.

RELEASE_DIR="$(cd "$CLI_DIR/.." && pwd)"
SETUP_SCRIPT="$RELEASE_DIR/setup.sh"
EXAMPLE_ENV="$RELEASE_DIR/.env.octopus.example"

# shellcheck source=./ui.sh
source "$CLI_DIR/lib/ui.sh"

if [[ ! -f "$SETUP_SCRIPT" ]]; then
  ui_error "setup.sh not found at $SETUP_SCRIPT"
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
SETUP_BUNDLE=""
SETUP_SCOPE=""
SETUP_STACK=""
SETUP_REVIEWERS=""
SETUP_HOOKS="true"
SETUP_WORKFLOW="true"
SETUP_DRY_RUN="false"
_setup_remaining_args=()
_setup_prev_arg=""

for _setup_arg in "$@"; do
  case "$_setup_arg" in
    --bundle=*)    SETUP_BUNDLE="${_setup_arg#--bundle=}" ;;
    --scope=*)     SETUP_SCOPE="${_setup_arg#--scope=}" ;;
    --stack=*)     SETUP_STACK="${_setup_arg#--stack=}" ;;
    --reviewers=*) SETUP_REVIEWERS="${_setup_arg#--reviewers=}" ;;
    --no-hooks)    SETUP_HOOKS="false" ;;
    --no-workflow) SETUP_WORKFLOW="false" ;;
    --dry-run)     SETUP_DRY_RUN="true"; export OCTOPUS_DRY_RUN="true" ;;
    --reconfigure) _setup_remaining_args+=("$_setup_arg") ;;
    --bundle|--scope|--stack|--reviewers) ;;  # value comes next iteration
    *)             _setup_remaining_args+=("$_setup_arg") ;;
  esac
  # Handle space-separated: --bundle starter
  case "$_setup_prev_arg" in
    --bundle)    SETUP_BUNDLE="$_setup_arg" ;;
    --scope)     SETUP_SCOPE="$_setup_arg" ;;
    --stack)     SETUP_STACK="$_setup_arg" ;;
    --reviewers) SETUP_REVIEWERS="$_setup_arg" ;;
  esac
  _setup_prev_arg="$_setup_arg"
done
unset _setup_arg _setup_prev_arg

# Normalise --bundle: accept comma or space-separated list → space-separated
SETUP_BUNDLE=$(printf '%s' "$SETUP_BUNDLE" | tr ',' ' ' | tr -s ' ')

# ---------------------------------------------------------------------------
# Resolve scope
# ---------------------------------------------------------------------------
if [[ -n "$SETUP_SCOPE" ]]; then
  export OCTOPUS_SCOPE="$SETUP_SCOPE"
  export OCTOPUS_SCOPE_PINNED=1
fi
OCTOPUS_SCOPE="${OCTOPUS_SCOPE:-repo}"
export OCTOPUS_SCOPE

case "$OCTOPUS_SCOPE" in
  repo|user) ;;
  *) ui_error "Invalid --scope '$OCTOPUS_SCOPE' — use 'repo' or 'user'."; exit 1 ;;
esac

export PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
USER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/octopus"

if [[ "$OCTOPUS_SCOPE" == "user" ]]; then
  MANIFEST_DIR="$USER_CONFIG_DIR"
else
  MANIFEST_DIR="$PROJECT_ROOT"
fi
MANIFEST_PATH="$MANIFEST_DIR/.octopus.yml"
export MANIFEST_PATH

# ---------------------------------------------------------------------------
# Manifest generation
# ---------------------------------------------------------------------------
_setup_generate_manifest() {
  local bundles_str="$1" hooks="$2" workflow="$3" reviewers="$4" stack="$5"

  mkdir -p "$(dirname "$MANIFEST_PATH")"

  {
    printf '# Edit and re-run '"'"'octopus setup'"'"' to apply changes.\n'
    printf 'agents:\n  - claude\n'
    printf 'bundles:\n'
    local _b
    for _b in $bundles_str; do printf '  - %s\n' "$_b"; done

    if [[ -n "$stack" ]]; then
      case "$stack" in
        dotnet)
          printf 'skills:\n  - dotnet\n'
          printf 'rules:\n  - csharp\n'
          ;;
        node)
          printf 'rules:\n  - typescript\n'
          ;;
      esac
    fi

    [[ "$hooks" == "true" ]]    && printf 'hooks: true\n'
    [[ "$workflow" == "true" ]] && printf 'workflow: true\n'

    if [[ -n "$reviewers" ]]; then
      printf 'reviewers:\n'
      local IFS=','
      for _r in $reviewers; do
        printf '  - %s\n' "${_r// /}"
      done
    fi

    printf '\n# Uncomment to configure:\n'
    printf '# reviewers: [user1, user2]\n'
    printf '# mcp:\n'
    printf '#   - name: github\n'
  } > "$MANIFEST_PATH"
}

# ---------------------------------------------------------------------------
# Interactive follow-up (reviewers)
# ---------------------------------------------------------------------------
_setup_prompt_reviewers() {
  printf "  GitHub usernames (comma-separated): "
  local reply
  read -r reply </dev/tty
  SETUP_REVIEWERS="$reply"
}

# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------
if [[ ! -f "$MANIFEST_PATH" ]]; then
  if [[ -n "$SETUP_BUNDLE" ]]; then
    # Flag-driven: no interaction
    _setup_generate_manifest \
      "$SETUP_BUNDLE" "$SETUP_HOOKS" "$SETUP_WORKFLOW" "$SETUP_REVIEWERS" "$SETUP_STACK"
  elif [[ -t 0 && -t 1 ]]; then
    # Interactive: launch picker
    source "$CLI_DIR/lib/setup-picker.sh"
    run_picker
    [[ "${PICKER_REVIEWERS:-}" == "__ask__" ]] && _setup_prompt_reviewers
    _setup_generate_manifest \
      "${PICKER_BUNDLES[*]:-starter}" \
      "${PICKER_HOOKS:-true}" \
      "${PICKER_WORKFLOW:-true}" \
      "${SETUP_REVIEWERS:-}" \
      "$SETUP_STACK"
  else
    # Non-interactive (CI/pipe): use defaults silently
    _setup_generate_manifest "starter" "true" "true" "" ""
  fi
elif [[ " ${_setup_remaining_args[*]:-} " == *" --reconfigure "* ]]; then
  # Reconfigure existing manifest
  if [[ -t 0 && -t 1 ]]; then
    source "$CLI_DIR/lib/setup-picker.sh"
    run_picker
    [[ "${PICKER_REVIEWERS:-}" == "__ask__" ]] && _setup_prompt_reviewers
    _setup_generate_manifest \
      "${PICKER_BUNDLES[*]:-starter}" \
      "${PICKER_HOOKS:-true}" \
      "${PICKER_WORKFLOW:-true}" \
      "${SETUP_REVIEWERS:-}" \
      "$SETUP_STACK"
  fi
fi

# Delegate delivery to root setup.sh
bash "$SETUP_SCRIPT" "${_setup_remaining_args[@]+"${_setup_remaining_args[@]}"}"
