# update.sh — Update Octopus submodule to a target version
# Usage: octopus.sh update [--version <tag>] [--latest]

TARGET_VERSION=""
USE_LATEST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) TARGET_VERSION="$2"; shift 2 ;;
    --latest)  USE_LATEST=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Resolve octopus submodule directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OCTOPUS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="$(cd "$OCTOPUS_DIR/.." && pwd)"

# Validate we're inside a submodule
if [[ ! -f "$OCTOPUS_DIR/setup.sh" ]]; then
  echo "ERROR: Cannot locate octopus setup.sh. Run from your project root."
  exit 1
fi

CURRENT_VERSION=$(git -C "$OCTOPUS_DIR" describe --tags --exact-match 2>/dev/null || echo "unknown")
echo "Current octopus version: $CURRENT_VERSION"

# Fetch tags from remote
echo "Fetching available versions..."
git -C "$OCTOPUS_DIR" fetch --tags --quiet

# List available versions
VERSIONS=$(git -C "$OCTOPUS_DIR" tag -l 'v*' | sort -V)
LATEST=$(echo "$VERSIONS" | tail -1)

if [[ -z "$VERSIONS" ]]; then
  echo "ERROR: No versioned tags found in octopus remote."
  exit 1
fi

echo ""
echo "Available versions:"
echo "$VERSIONS" | tail -5 | awk '{print "  " $0}'

if $USE_LATEST || [[ -z "$TARGET_VERSION" ]]; then
  TARGET_VERSION="$LATEST"
fi

echo ""
echo "Target version: $TARGET_VERSION"

if [[ "$CURRENT_VERSION" == "$TARGET_VERSION" ]]; then
  echo "Already at $TARGET_VERSION — nothing to do."
  exit 0
fi

# Validate target tag exists
if ! git -C "$OCTOPUS_DIR" tag -l | grep -qx "$TARGET_VERSION"; then
  echo "ERROR: Version '$TARGET_VERSION' not found. Available: $(git -C "$OCTOPUS_DIR" tag -l 'v*' | tr '\n' ' ')"
  exit 1
fi

# Checkout target version
echo "Checking out $TARGET_VERSION..."
git -C "$OCTOPUS_DIR" checkout "$TARGET_VERSION" --quiet

# Re-run setup
echo "Running setup.sh..."
bash "$OCTOPUS_DIR/setup.sh"

# Stage and commit submodule update
cd "$PROJECT_ROOT"
git add octopus
git commit -m "chore: update octopus to $TARGET_VERSION"

echo ""
echo "OCTOPUS_UPDATED=$TARGET_VERSION"
echo "Octopus updated from $CURRENT_VERSION to $TARGET_VERSION."
