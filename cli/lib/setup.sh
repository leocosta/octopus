# cli/lib/setup.sh — Configure Octopus in the current repository
# Delegates to the root setup.sh bundled with the release.

# 1. Fix PROJECT_ROOT — the global shim already cds to the project root before
#    invoking the CLI, so $PWD is always the user's project at this point.
#    Exporting here prevents setup.sh from falling back to its own parent dir
#    (~/.octopus-cli/cache/) instead of the user's project.
export PROJECT_ROOT="$PWD"

# 2. Derive paths from CLI_DIR (set by cli/octopus.sh before sourcing this file)
RELEASE_DIR="$(cd "$CLI_DIR/.." && pwd)"
SETUP_SCRIPT="$RELEASE_DIR/setup.sh"
EXAMPLE_YML="$RELEASE_DIR/.octopus.example.yml"
EXAMPLE_ENV="$RELEASE_DIR/.env.octopus.example"

if [[ ! -f "$SETUP_SCRIPT" ]]; then
  echo "ERROR: setup.sh not found at $SETUP_SCRIPT"
  exit 1
fi

# 3. Prompt helper — default yes, safe for non-interactive (piped) execution
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

# 4. Scaffold .octopus.yml if missing
if [[ ! -f "$PROJECT_ROOT/.octopus.yml" ]]; then
  echo ""
  echo "No .octopus.yml found in: $PROJECT_ROOT"

  if [[ ! -f "$EXAMPLE_YML" ]]; then
    echo "WARNING: template not found at $EXAMPLE_YML — skipping scaffold."
  elif _ask_yes "Create .octopus.yml from template?"; then
    cp "$EXAMPLE_YML" "$PROJECT_ROOT/.octopus.yml"
    echo "Created: $PROJECT_ROOT/.octopus.yml"
    echo "  -> Edit it and re-run 'octopus setup', or continue now with defaults."
    echo ""
  else
    echo "Skipped. Re-run 'octopus setup' after creating .octopus.yml."
    exit 0
  fi
fi

# 5. Scaffold .env.octopus if missing (always, no prompt — it's safe boilerplate)
if [[ ! -f "$PROJECT_ROOT/.env.octopus" ]]; then
  if [[ -f "$EXAMPLE_ENV" ]]; then
    cp "$EXAMPLE_ENV" "$PROJECT_ROOT/.env.octopus"
    echo "Created: $PROJECT_ROOT/.env.octopus"
    echo "  -> Fill in your API tokens before running integrations."
    echo ""
  fi
fi

# 6. Delegate to the release setup.sh
bash "$SETUP_SCRIPT" "$@"
