# cli/lib/setup.sh — Configure Octopus in the current repository
# Delegates to the root setup.sh bundled with the release.

SETUP_SCRIPT="$CLI_DIR/../setup.sh"

if [[ ! -f "$SETUP_SCRIPT" ]]; then
  echo "ERROR: setup.sh not found at $SETUP_SCRIPT"
  exit 1
fi

bash "$SETUP_SCRIPT" "$@"
