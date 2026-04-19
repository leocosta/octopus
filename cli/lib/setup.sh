# cli/lib/setup.sh — Configure Octopus in the current repository or at user scope.
# Delegates to the root setup.sh bundled with the release.

# 1. Derive paths from CLI_DIR (set by cli/octopus.sh before sourcing this file)
RELEASE_DIR="$(cd "$CLI_DIR/.." && pwd)"
SETUP_SCRIPT="$RELEASE_DIR/setup.sh"
EXAMPLE_YML="$RELEASE_DIR/.octopus.example.yml"
EXAMPLE_ENV="$RELEASE_DIR/.env.octopus.example"

# shellcheck source=./ui.sh
source "$CLI_DIR/lib/ui.sh"

if [[ ! -f "$SETUP_SCRIPT" ]]; then
  ui_error "setup.sh not found at $SETUP_SCRIPT"
  exit 1
fi

# 2. Parse CLI flags. We accept --scope=<value> and --reconfigure here;
# everything else flows through to setup.sh unchanged.
CLI_SCOPE=""
RECONFIGURE_FLAG=""
_remaining_args=()
for _arg in "$@"; do
  case "$_arg" in
    --scope=*)    CLI_SCOPE="${_arg#--scope=}" ;;
    --reconfigure) RECONFIGURE_FLAG="--reconfigure" ;;
    *)             _remaining_args+=("$_arg") ;;
  esac
done

# 3. Resolve effective scope. Precedence: --scope CLI flag > OCTOPUS_SCOPE env
# var > (wizard prompt asks) > repo default applied inside setup.sh.
# OCTOPUS_SCOPE_PINNED=1 tells the wizard to skip the scope prompt because
# we already have an explicit user decision.
OCTOPUS_SCOPE_PINNED=""
if [[ -n "$CLI_SCOPE" ]]; then
  export OCTOPUS_SCOPE="$CLI_SCOPE"
  OCTOPUS_SCOPE_PINNED=1
elif [[ -n "${OCTOPUS_SCOPE:-}" ]]; then
  OCTOPUS_SCOPE_PINNED=1
fi
OCTOPUS_SCOPE="${OCTOPUS_SCOPE:-repo}"
export OCTOPUS_SCOPE OCTOPUS_SCOPE_PINNED

case "$OCTOPUS_SCOPE" in
  repo|user) ;;
  *) ui_error "Invalid --scope '$OCTOPUS_SCOPE' — use 'repo' or 'user'."; exit 1 ;;
esac

# 4. Fix PROJECT_ROOT + MANIFEST_PATH based on scope.
# Repo scope: manifest lives next to the codebase (PWD set by bin/octopus).
# User scope: manifest lives in XDG config; PROJECT_ROOT still tracks the repo
# because some downstream paths (OCTOPUS_DIR fallbacks in setup.sh) need a
# sensible working directory.
export PROJECT_ROOT="$PWD"
USER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/octopus"

if [[ "$OCTOPUS_SCOPE" == "user" ]]; then
  MANIFEST_DIR="$USER_CONFIG_DIR"
else
  MANIFEST_DIR="$PROJECT_ROOT"
fi
MANIFEST_PATH="$MANIFEST_DIR/.octopus.yml"
ENV_PATH="$MANIFEST_DIR/.env.octopus"

# 5. Prompt helper — default yes, safe for non-interactive (piped) execution
_ask_yes() {
  local prompt="$1"
  if [[ ! -t 0 ]]; then return 0; fi  # non-interactive: default yes silently
  local reply
  read -r -p "$prompt [Y/n] " reply
  case "${reply,,}" in
    n|no) return 1 ;;
    *)    return 0 ;;
  esac
}

# 6. Interactive wizard for first-time setup or reconfiguration
if [[ ! -f "$MANIFEST_PATH" ]]; then
  ui_info "No .octopus.yml found at: $MANIFEST_PATH"

  if [[ -t 0 && -t 1 ]]; then
    # Interactive: run the setup wizard. It writes to $MANIFEST_DIR/.octopus.yml.
    mkdir -p "$MANIFEST_DIR"
    source "$CLI_DIR/lib/setup-wizard.sh"
    run_setup_wizard "$MANIFEST_DIR" "$RELEASE_DIR"

    # If wizard was non-interactive, fall back to template copy
    if [[ ! -f "$MANIFEST_PATH" ]]; then
      if [[ -f "$EXAMPLE_YML" ]]; then
        mkdir -p "$(dirname "$MANIFEST_PATH")"
        cp "$EXAMPLE_YML" "$MANIFEST_PATH"
        ui_success "Created $MANIFEST_PATH"
        ui_info "Edit it and re-run 'octopus setup', or continue now with defaults."
      else
        ui_warn "template not found at $EXAMPLE_YML — skipping scaffold."
      fi
    fi
  else
    # Non-interactive: copy template as before
    if [[ ! -f "$EXAMPLE_YML" ]]; then
      ui_warn "template not found at $EXAMPLE_YML — skipping scaffold."
    elif _ask_yes "Create .octopus.yml from template?"; then
      mkdir -p "$(dirname "$MANIFEST_PATH")"
      cp "$EXAMPLE_YML" "$MANIFEST_PATH"
      ui_success "Created $MANIFEST_PATH"
      ui_info "Edit it and re-run 'octopus setup', or continue now with defaults."
    else
      ui_info "Skipped. Re-run 'octopus setup' after creating $MANIFEST_PATH."
      exit 0
    fi
  fi

elif [[ "$RECONFIGURE_FLAG" == "--reconfigure" ]]; then
  # Reconfigure existing manifest interactively
  if [[ -t 0 && -t 1 ]]; then
    ui_info "Reconfiguring $MANIFEST_PATH..."
    source "$CLI_DIR/lib/setup-wizard.sh"
    run_setup_wizard "$MANIFEST_DIR" "$RELEASE_DIR" "--reconfigure"
  else
    ui_warn "--reconfigure requires an interactive terminal."
    exit 1
  fi
fi

# 7. Scaffold .env.octopus if missing (safe boilerplate, no prompt)
if [[ ! -f "$ENV_PATH" ]]; then
  if [[ -f "$EXAMPLE_ENV" ]]; then
    mkdir -p "$(dirname "$ENV_PATH")"
    cp "$EXAMPLE_ENV" "$ENV_PATH"
    [[ "$OCTOPUS_SCOPE" == "user" ]] && chmod 600 "$ENV_PATH" 2>/dev/null || true
    ui_success "Created $ENV_PATH"
    ui_info "Fill in your API tokens before running integrations."
  fi
fi

# 8. Delegate to the release setup.sh with the remaining args.
bash "$SETUP_SCRIPT" "${_remaining_args[@]}"
