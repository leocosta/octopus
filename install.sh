#!/usr/bin/env bash
set -euo pipefail

# Octopus CLI Installer
# Downloads Octopus releases from GitHub and installs the global CLI.
#
# Usage:
#   curl -fsSL https://github.com/leocosta/octopus/releases/latest/download/install.sh | bash
#   # Or with a specific version:
#   curl -fsSL https://github.com/leocosta/octopus/releases/download/v0.15.0/install.sh | bash -s -- --version v0.15.0

OCTOPUS_CACHE_DIR="${OCTOPUS_CACHE_DIR:-$HOME/.octopus-cli}"
OCTOPUS_BIN_DIR="${OCTOPUS_BIN_DIR:-$HOME/.local/bin}"
GITHUB_REPO="leocosta/octopus"
GITHUB_API="https://api.github.com/repos/$GITHUB_REPO"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}ℹ  $1${NC}"; }
success() { echo -e "${GREEN}✓  $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $1${NC}"; }
error()   { echo -e "${RED}✗  $1${NC}" >&2; }

# Parse arguments
VERSION=""
FORCE=false
UNINSTALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v)
      VERSION="${2:-}"
      if [[ -z "$VERSION" ]]; then
        error "Missing version argument."
        echo "Usage: install.sh --version v0.15.0" >&2
        exit 1
      fi
      shift 2
      ;;
    --force|-f)
      FORCE=true
      shift
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    --help|-h)
      echo "Octopus CLI Installer"
      echo ""
      echo "Usage:"
      echo "  install.sh                    Install latest version"
      echo "  install.sh --version v0.15.0  Install specific version"
      echo "  install.sh --force            Reinstall even if already installed"
      echo "  install.sh --uninstall        Remove Octopus CLI"
      echo "  install.sh --help             Show this help"
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Uninstall mode
if [[ "$UNINSTALL" = true ]]; then
  info "Uninstalling Octopus CLI..."
  rm -f "$OCTOPUS_BIN_DIR/octopus"
  rm -rf "$OCTOPUS_CACHE_DIR"
  success "Octopus CLI removed."
  exit 0
fi

# Check prerequisites
check_prerequisites() {
  local missing=()
  for cmd in curl tar bash; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required commands: ${missing[*]}"
    exit 1
  fi
}

# Fetch the latest release tag from GitHub API
get_latest_version() {
  local latest
  latest="$(curl -fsSL "$GITHUB_API/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name":[[:space:]]*"//' | sed 's/".*//')"
  if [[ -z "$latest" ]]; then
    error "Could not determine latest version from GitHub."
    exit 1
  fi
  echo "$latest"
}

# Download and extract a release
download_release() {
  local version="$1"
  local dest="$OCTOPUS_CACHE_DIR/$version"

  if [[ -d "$dest" && "$FORCE" != true ]]; then
    info "Octopus $version already cached at $dest"
    return 0
  fi

  info "Downloading Octopus $version..."

  # Create temp directory for extraction
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" EXIT

  # Download tarball
  local url="https://github.com/$GITHUB_REPO/archive/refs/tags/$version.tar.gz"
  if ! curl -fsSL "$url" -o "$tmpdir/octopus.tar.gz"; then
    error "Failed to download $version."
    echo "Check that the tag exists: https://github.com/$GITHUB_REPO/releases" >&2
    exit 1
  fi

  # Extract
  tar -xzf "$tmpdir/octopus.tar.gz" -C "$tmpdir"

  # The tarball extracts into octopus-<version>/ or octopus-<tag>/
  local extracted_dir
  extracted_dir="$(find "$tmpdir" -maxdepth 1 -type d -name 'octopus-*' | head -1)"
  if [[ -z "$extracted_dir" ]]; then
    error "Unexpected tarball structure."
    exit 1
  fi

  # Move to cache
  mkdir -p "$OCTOPUS_CACHE_DIR"
  rm -rf "$dest" 2>/dev/null || true
  mv "$extracted_dir" "$dest"

  success "Octopus $version downloaded to $dest"
}

# Update the "current" symlink
update_symlink() {
  local version="$1"
  local target="$OCTOPUS_CACHE_DIR/$version"

  # Remove old symlink
  rm -f "$OCTOPUS_CACHE_DIR/current"

  # Create new symlink
  ln -sf "$target" "$OCTOPUS_CACHE_DIR/current"

  info "Symlinked $OCTOPUS_CACHE_DIR/current -> $version"
}

# Install the shim
install_shim() {
  mkdir -p "$OCTOPUS_BIN_DIR"

  # Determine the source of the shim
  # Try to get it from the downloaded release first, fall back to inline
  local shim_source="$OCTOPUS_CACHE_DIR/current/bin/octopus"

  if [[ -f "$shim_source" ]]; then
    cp "$shim_source" "$OCTOPUS_BIN_DIR/octopus"
  else
    # Inline shim (fallback — should not happen with proper releases)
    cat > "$OCTOPUS_BIN_DIR/octopus" << 'SHIM'
#!/usr/bin/env bash
set -euo pipefail
OCTOPUS_CACHE_DIR="${OCTOPUS_CACHE_DIR:-$HOME/.octopus-cli}"
resolve_octopus_dir() {
  local lockfile=""
  local search_dir="$(pwd)"
  while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/.octopus/cli-lock.yaml" ]]; then
      lockfile="$search_dir/.octopus/cli-lock.yaml"
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done
  local version=""
  if [[ -n "$lockfile" ]]; then
    version="$(grep -E '^version:' "$lockfile" | head -1 | sed 's/version:[[:space:]]*//' | tr -d '"' | tr -d "'" | xargs)"
  fi
  if [[ -n "$version" && -d "$OCTOPUS_CACHE_DIR/$version" ]]; then
    echo "$OCTOPUS_CACHE_DIR/$version"
    return 0
  fi
  if [[ -L "$OCTOPUS_CACHE_DIR/current" && -d "$OCTOPUS_CACHE_DIR/current" ]]; then
    echo "$OCTOPUS_CACHE_DIR/current"
    return 0
  fi
  if [[ -d "$OCTOPUS_CACHE_DIR" ]]; then
    local latest=""
    latest="$(ls -1 "$OCTOPUS_CACHE_DIR" 2>/dev/null | grep '^v[0-9]' | sort -V | tail -1)"
    if [[ -n "$latest" ]]; then
      echo "$OCTOPUS_CACHE_DIR/$latest"
      return 0
    fi
  fi
  return 1
}
main() {
  local octopus_dir
  if ! octopus_dir="$(resolve_octopus_dir)"; then
    echo "Octopus is not installed in this project." >&2
    echo "" >&2
    echo "Install the global CLI:" >&2
    echo "  curl -fsSL https://github.com/leocosta/octopus/releases/latest/download/install.sh | bash" >&2
    echo "" >&2
    echo "Or add Octopus as a submodule:" >&2
    echo "  git submodule add git@github.com:leocosta/octopus.git octopus" >&2
    echo "  ./octopus/setup.sh" >&2
    exit 1
  fi
  local cli_script="$octopus_dir/cli/octopus.sh"
  if [[ ! -f "$cli_script" ]]; then
    echo "Error: cli/octopus.sh not found in $octopus_dir" >&2
    exit 1
  fi
  exec bash "$cli_script" "$@"
}
main "$@"
SHIM
  fi

  chmod +x "$OCTOPUS_BIN_DIR/octopus"
  success "Installed shim to $OCTOPUS_BIN_DIR/octopus"
}

# Check if bin dir is in PATH
check_path() {
  if [[ ":$PATH:" != *":$OCTOPUS_BIN_DIR:"* ]]; then
    warn "$OCTOPUS_BIN_DIR is not in your PATH."
    echo ""
    echo "Add it to your shell profile:"
    echo "  echo 'export PATH=\"$OCTOPUS_BIN_DIR:\$PATH\"' >> ~/.bashrc  # or ~/.zshrc"
    echo "  source ~/.bashrc"
    echo ""
  fi
}

# Main installation flow
main() {
  echo ""
  echo "  ___                   _"
  echo " / _ \ _ __   ___ _ __ | | ___"
  echo "| | | | '_ \ / _ \ '_ \| |/ _ \\"
  echo "| |_| | |_) |  __/ | | | |  __/"
  echo " \___/| .__/ \___|_| |_|_|\___|"
  echo "      |_|"
  echo ""
  echo "  Octopus CLI Installer"
  echo ""

  check_prerequisites

  # Determine version
  if [[ -z "$VERSION" ]]; then
    info "No version specified, fetching latest..."
    VERSION="$(get_latest_version)"
  fi

  success "Installing Octopus $VERSION"

  # Download
  download_release "$VERSION"

  # Symlink
  update_symlink "$VERSION"

  # Install shim
  install_shim

  # Path check
  check_path

  echo ""
  success "Octopus CLI installed successfully!"
  echo ""
  echo "Usage:"
  echo "  octopus                           Show available commands"
  echo "  octopus branch-create             Create a development branch"
  echo "  octopus dev-flow                  Run guided development workflow"
  echo "  octopus pr-open                   Open a PR"
  echo "  octopus pr-review                 Self-review a PR"
  echo "  octopus pr-merge                  Merge an approved PR"
  echo "  octopus pr-comments               Address PR review comments"
  echo "  octopus release                   Create a versioned release"
  echo "  octopus update                    Update Octopus"
  echo "  octopus doc-spec                  Create a feature spec"
  echo "  octopus doc-rfc                   Create an RFC"
  echo "  octopus doc-adr                   Create an ADR"
  echo "  octopus doc-research              Conduct research session"
  echo ""
  echo "Uninstall:"
  echo "  curl -fsSL https://github.com/leocosta/octopus/releases/latest/download/install.sh | bash -s -- --uninstall"
  echo ""
}

main "$@"
