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
METADATA_FILE="$OCTOPUS_CACHE_DIR/metadata.json"
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
    --bin-dir)
      OCTOPUS_BIN_DIR="${2:-}"
      if [[ -z "$OCTOPUS_BIN_DIR" ]]; then
        error "Missing --bin-dir argument."
        exit 1
      fi
      shift 2
      ;;
    --cache-root)
      OCTOPUS_CACHE_DIR="${2:-}"
      if [[ -z "$OCTOPUS_CACHE_DIR" ]]; then
        error "Missing --cache-root argument."
        exit 1
      fi
      METADATA_FILE="$OCTOPUS_CACHE_DIR/metadata.json"
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
      echo "  install.sh --bin-dir <path>   Override default shim directory"
      echo "  install.sh --cache-root <path> Override ~/.octopus-cli cache location"
      echo "  install.sh --force            Reinstall even if already installed"
      echo "  install.sh --uninstall        Remove Octopus CLI"
      echo "  install.sh --help             Show this help"
      echo ""
      echo "Environment:"
      echo "  OCTOPUS_INSTALL_ENDPOINT  Base URL for tarball + checksum + signature (supports file://)"
      echo "  OCTOPUS_GPG_KEYRING       Custom keyring file for signature verification"
      echo "  OCTOPUS_GPG_IMPORT_KEY    ASCII-armored public key to import before verifying"
      echo "  OCTOPUS_REQUIRE_SIGNATURE Set to 1 to refuse installs without a published .asc"
      echo "  OCTOPUS_SKIP_SIGNATURE    Set to 1 to bypass GPG verification (not recommended)"
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

# Resolve the base URL for release artifacts.
# When OCTOPUS_INSTALL_ENDPOINT is set, artifacts live at <endpoint>/<version>/
# (supports file:// for tests/offline mirrors). Otherwise use the GitHub archive URL.
resolve_tarball_url() {
  local version="$1"
  if [[ -n "${OCTOPUS_INSTALL_ENDPOINT:-}" ]]; then
    echo "${OCTOPUS_INSTALL_ENDPOINT%/}/$version/octopus-$version.tar.gz"
  else
    echo "https://github.com/$GITHUB_REPO/archive/refs/tags/$version.tar.gz"
  fi
}

resolve_checksum_url() {
  local version="$1"
  if [[ -n "${OCTOPUS_INSTALL_ENDPOINT:-}" ]]; then
    echo "${OCTOPUS_INSTALL_ENDPOINT%/}/$version/octopus-$version.sha256"
  fi
}

resolve_signature_url() {
  local version="$1"
  if [[ -n "${OCTOPUS_INSTALL_ENDPOINT:-}" ]]; then
    echo "${OCTOPUS_INSTALL_ENDPOINT%/}/$version/octopus-$version.tar.gz.asc"
  fi
}

# Verify the tarball's detached GPG signature against a trusted public key.
# Honored env vars:
#   OCTOPUS_GPG_KEYRING     — use this keyring instead of the default user one
#   OCTOPUS_GPG_IMPORT_KEY  — path to an ASCII-armored public key to import first
#   OCTOPUS_SKIP_SIGNATURE  — set to 1 to disable signature verification (not recommended)
verify_signature() {
  local tarball="$1"
  local signature="$2"

  if [[ "${OCTOPUS_SKIP_SIGNATURE:-0}" == "1" ]]; then
    warn "Skipping GPG signature verification (OCTOPUS_SKIP_SIGNATURE=1)."
    return 0
  fi

  if ! command -v gpg &>/dev/null; then
    error "gpg not found — install GnuPG or set OCTOPUS_SKIP_SIGNATURE=1 to bypass."
    return 1
  fi

  local gpg_args=(--verify --batch --no-auto-key-locate)

  # Optional custom keyring overrides the user's default.
  if [[ -n "${OCTOPUS_GPG_KEYRING:-}" ]]; then
    if [[ ! -f "$OCTOPUS_GPG_KEYRING" ]]; then
      error "OCTOPUS_GPG_KEYRING=$OCTOPUS_GPG_KEYRING: file not found."
      return 1
    fi
    gpg_args=(--verify --batch --no-default-keyring --keyring "$OCTOPUS_GPG_KEYRING")
  elif [[ -n "${OCTOPUS_GPG_IMPORT_KEY:-}" && -f "${OCTOPUS_GPG_IMPORT_KEY}" ]]; then
    # Import the supplied key into the default keyring once; idempotent.
    gpg --batch --quiet --import "${OCTOPUS_GPG_IMPORT_KEY}" >/dev/null 2>&1 || true
  fi

  if ! gpg "${gpg_args[@]}" "$signature" "$tarball" >/dev/null 2>&1; then
    error "GPG signature verification failed for $(basename "$tarball")."
    echo "  Set OCTOPUS_GPG_KEYRING or OCTOPUS_GPG_IMPORT_KEY to a trusted key," >&2
    echo "  or OCTOPUS_SKIP_SIGNATURE=1 to bypass (not recommended)." >&2
    return 1
  fi
}

# Exported so write_metadata can embed the verified checksum.
DOWNLOADED_CHECKSUM=""

# Download and extract a release
download_release() {
  local version="$1"
  local dest="$OCTOPUS_CACHE_DIR/cache/$version"

  if [[ -d "$dest" && "$FORCE" != true ]]; then
    info "Octopus $version already cached at $dest"
    return 0
  fi

  info "Downloading Octopus $version..."

  # Create temp directory for extraction
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" EXIT

  # Download tarball (show progress bar)
  local url
  url="$(resolve_tarball_url "$version")"
  if ! curl -fL --progress-bar "$url" -o "$tmpdir/octopus.tar.gz"; then
    error "Failed to download $version from $url."
    echo "Check that the tag exists: https://github.com/$GITHUB_REPO/releases" >&2
    exit 1
  fi

  # Verify SHA256 when the endpoint publishes a companion checksum file.
  local checksum_url
  checksum_url="$(resolve_checksum_url "$version")"
  if [[ -n "$checksum_url" ]]; then
    if ! curl -fsSL "$checksum_url" -o "$tmpdir/octopus.sha256"; then
      error "Failed to download checksum from $checksum_url."
      exit 1
    fi
    local expected actual
    expected="$(awk '{print $1}' "$tmpdir/octopus.sha256")"
    actual="$(sha256sum "$tmpdir/octopus.tar.gz" | awk '{print $1}')"
    if [[ "$expected" != "$actual" ]]; then
      error "Checksum mismatch for $version (expected $expected, got $actual)."
      exit 1
    fi
    DOWNLOADED_CHECKSUM="$actual"
  else
    DOWNLOADED_CHECKSUM="$(sha256sum "$tmpdir/octopus.tar.gz" | awk '{print $1}')"
  fi

  # Verify GPG signature when the endpoint publishes a detached .asc file.
  # SHA256 protects against transport corruption; the signature protects
  # against a compromised mirror serving a tampered tarball with a matching
  # checksum file. Both are required when present.
  local signature_url
  signature_url="$(resolve_signature_url "$version")"
  if [[ -n "$signature_url" ]]; then
    # Probe for availability — some mirrors may not publish signatures yet.
    # 'curl --fail' turns 404 into a non-zero exit.
    if curl -fsSL "$signature_url" -o "$tmpdir/octopus.tar.gz.asc" 2>/dev/null; then
      info "Verifying GPG signature..."
      verify_signature "$tmpdir/octopus.tar.gz" "$tmpdir/octopus.tar.gz.asc" || exit 1
      success "Signature valid."
    elif [[ "${OCTOPUS_REQUIRE_SIGNATURE:-0}" == "1" ]]; then
      error "No signature published at $signature_url (OCTOPUS_REQUIRE_SIGNATURE=1)."
      exit 1
    fi
  fi

  # Extract
  info "Extracting..."
  tar -xzf "$tmpdir/octopus.tar.gz" -C "$tmpdir"

  # The tarball extracts into octopus-<version>/ or octopus-<tag>/
  local extracted_dir
  extracted_dir="$(find "$tmpdir" -maxdepth 1 -type d -name 'octopus-*' | head -1)"
  if [[ -z "$extracted_dir" ]]; then
    error "Unexpected tarball structure."
    exit 1
  fi

  # Move to cache
  mkdir -p "$OCTOPUS_CACHE_DIR/cache"
  rm -rf "$dest" 2>/dev/null || true
  mv "$extracted_dir" "$dest"

  success "Octopus $version cached at $dest"
}

# Update the "current" symlink
update_symlink() {
  local version="$1"
  local target="$OCTOPUS_CACHE_DIR/cache/$version"

  rm -f "$OCTOPUS_CACHE_DIR/current"
  ln -sf "$target" "$OCTOPUS_CACHE_DIR/current"
}

# Write metadata.json so the shim can resolve the version without git
write_metadata() {
  local version="$1"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "$METADATA_FILE")"
  cat > "$METADATA_FILE" <<EOF
{
  "version": "$version",
  "checksum": "$DOWNLOADED_CHECKSUM",
  "installed_at": "$timestamp",
  "release_path": "$OCTOPUS_CACHE_DIR/cache/$version"
}
EOF
}

# Install the shim
install_shim() {
  mkdir -p "$OCTOPUS_BIN_DIR"

  cat > "$OCTOPUS_BIN_DIR/octopus" << 'OCTOPUS_SHIM_EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_ROOT="${OCTOPUS_CLI_CACHE_ROOT:-$HOME/.octopus-cli}"
CACHE_DIR="$CACHE_ROOT/cache"
METADATA_FILE="$CACHE_ROOT/metadata.json"

# Determine RELEASE_ROOT: prefer local submodule, fall back to globally cached release.
# Uses plain readlink (no -f) because current always points to an absolute path.
_resolve_release_root() {
  local candidate
  candidate="$(cd "$SCRIPT_DIR/.." && pwd)"
  if [[ -f "$candidate/cli/octopus.sh" ]]; then
    echo "$candidate"
  elif [[ -L "$CACHE_ROOT/current" ]]; then
    readlink "$CACHE_ROOT/current"
  else
    echo "$candidate"
  fi
}
RELEASE_ROOT="$(_resolve_release_root)"

LOCKFILE_NAME=".octopus/cli-lock.yaml"

RELEASE_OWNER="${OCTOPUS_RELEASE_OWNER:-leocosta}"
RELEASE_REPO="${OCTOPUS_RELEASE_NAME:-octopus}"
API_ENDPOINT="${OCTOPUS_API_ENDPOINT:-https://api.github.com/repos/$RELEASE_OWNER/$RELEASE_REPO/releases/latest}"

cli_version_from_git() {
  git -C "$RELEASE_ROOT" describe --tags --abbrev=0 2>/dev/null \
    || git -C "$RELEASE_ROOT" rev-parse --short HEAD 2>/dev/null \
    || true
}

resolve_latest_remote_version() {
  local payload
  payload="$(curl -fsSL "$API_ENDPOINT" 2>/dev/null || true)"
  if [[ -n "$payload" ]]; then
    printf '%s' "$payload" | grep '"tag_name"' | head -n1 | sed -E 's/.*"([^"]+)".*/\1/'
  fi
}

find_lockfile() {
  local dir="$PWD"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -f "$dir/$LOCKFILE_NAME" ]]; then
      echo "$dir/$LOCKFILE_NAME"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

read_lock_version() {
  local lockfile="$1"
  grep -E '^version:' "$lockfile" 2>/dev/null | awk '{print $2}' | head -n1
}

read_metadata_field() {
  local key="$1"
  [[ -f "$METADATA_FILE" ]] || return 1
  grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$METADATA_FILE" \
    | sed -E "s/\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"/\\1/" \
    | head -n1
}

resolve_version() {
  if lockfile="$(find_lockfile)"; then
    local lock_version
    lock_version="$(read_lock_version "$lockfile")"
    [[ -n "$lock_version" ]] && { echo "$lock_version"; return 0; }
  fi
  local meta_version
  meta_version="$(read_metadata_field "version" || true)"
  if [[ -n "$meta_version" ]]; then
    echo "$meta_version"
    return 0
  fi
  cli_version_from_git
}

ensure_cache_dirs() {
  mkdir -p "$CACHE_DIR"
}

install_release() {
  local version="$1"
  ensure_cache_dirs
  local target="$CACHE_DIR/$version"
  if [[ "$RELEASE_ROOT" != "$target" && ( -e "$target" || -L "$target" ) ]]; then
    rm -rf "$target"
  fi
  if [[ "$RELEASE_ROOT" == "$target" ]]; then
    mkdir -p "$target"
  else
    ln -s "$RELEASE_ROOT" "$target"
  fi
  local checksum
  checksum="$(compute_release_checksum "$RELEASE_ROOT")"
  write_metadata "$version" "$checksum"
  echo "Installed Octopus $version (cached at $target)"
}

write_metadata() {
  local version="$1"
  local checksum="$2"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "$METADATA_FILE")"
  cat > "$METADATA_FILE" <<EOF
{
  "version": "$version",
  "checksum": "$checksum",
  "installed_at": "$timestamp",
  "release_path": "$RELEASE_ROOT"
}
EOF
}

compute_release_checksum() {
  local root="$1"
  if git -C "$root" rev-parse HEAD >/dev/null 2>&1; then
    git -C "$root" rev-parse HEAD
    return
  fi

  (cd "$root" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')
}

find_project_root() {
  local dir="$PWD"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -f "$dir/.octopus.yml" || -d "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "$PWD"
}

pin_lockfile() {
  local version="$1"
  local checksum="$2"
  local lockfile
  if lockfile="$(find_lockfile)"; then
    :
  else
    local project
    project="$(find_project_root)"
    lockfile="$project/$LOCKFILE_NAME"
  fi
  mkdir -p "$(dirname "$lockfile")"
  cat > "$lockfile" <<EOF
version: $version
checksum: $checksum
EOF
  echo "Pinned Octopus $version in $lockfile"
}

release_dir_for() {
  local version="$1"
  echo "$CACHE_DIR/$version"
}

ensure_release_for() {
  local version="$1"
  local release_dir
  release_dir="$(release_dir_for "$version")"
  if [[ ! -e "$release_dir" && ! -L "$release_dir" ]]; then
    install_release "$version"
  fi
}

doctor() {
  local version
  version="$(resolve_version)"
  if [[ -z "$version" ]]; then
    echo "No installed release."
    return 1
  fi
  local release_dir
  release_dir="$(release_dir_for "$version")"
  echo "Installed Octopus version: $version"
  echo "Tracked release directory: $release_dir"
  [[ -f "$METADATA_FILE" ]] && echo "Metadata: $METADATA_FILE"
  [[ -e "$release_dir" ]] && echo "Release available."
}

run_subcommand() {
  local command="$1"
  shift
  local version
  version="$(resolve_version)"
  ensure_release_for "$version"
  local project_root
  project_root="$(find_project_root)"
  local release_dir
  release_dir="$(release_dir_for "$version")"
  (cd "$project_root" && "$release_dir/cli/octopus.sh" "$command" "$@")
}

command_install() {
  local version=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        version="$2"
        shift 2
        ;;
      --latest)
        echo "Resolving latest version..."
        version="$(resolve_latest_remote_version || cli_version_from_git)"
        shift
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  if [[ -z "$version" ]]; then
    echo "Resolving latest version..."
    version="$(resolve_latest_remote_version || cli_version_from_git)"
  fi
  echo "Installing Octopus $version..."
  install_release "$version"
  echo "Done. Run 'octopus doctor' to verify."
}

command_update() {
  local version=""
  local pin=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        version="$2"
        shift 2
        ;;
      --latest)
        echo "Resolving latest version..."
        version="$(resolve_latest_remote_version || cli_version_from_git)"
        shift
        ;;
      --pin)
        pin=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  if [[ -z "$version" ]]; then
    echo "Resolving latest version..."
    version="$(resolve_version)"
  fi
  echo "Updating to Octopus $version..."
  install_release "$version"
  local checksum
  checksum="$(compute_release_checksum "$RELEASE_ROOT")"
  if [[ "$pin" == true ]]; then
    pin_lockfile "$version" "$checksum"
  fi
}

command_setup() {
  local version
  version="$(resolve_version)"
  ensure_release_for "$version"
  run_subcommand setup "$@"
}

print_help() {
  cat <<EOF
Usage: octopus <command> [args]

Commands:
  install [--version <tag>] [--latest]   Install a release into the local cache
  update [--version <tag>] [--latest] [--pin]
  setup [--scope=repo|user] [--reconfigure]
                                          Configure Octopus for this repo (default) or user account
  doctor                                 Inspect the cached installation
  <other>                                Delegate to the existing workflow CLI
EOF
}

command="${1:-}"
shift || true
case "$command" in
  install)
    command_install "$@"
    ;;
  update)
    command_update "$@"
    ;;
  setup)
    command_setup "$@"
    ;;
  doctor)
    doctor
    ;;
  "" | -h | --help)
    print_help
    ;;
  *)
    run_subcommand "$command" "$@"
    ;;
esac

OCTOPUS_SHIM_EOF


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
  echo -e "${GREEN}        ___"
  echo      "       /   \\"
  echo      "      | o o |"
  echo      "       \\_^_/"
  echo      "      /||||||\\"
  echo      "     / |||||| \\"
  echo -e   "    /  ||||||  \\\\${NC}"
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

  # Symlink and metadata
  update_symlink "$VERSION"
  write_metadata "$VERSION"

  # Install shim
  install_shim

  # Path check
  check_path

  echo ""
  echo -e "${GREEN}  ✓  Octopus CLI ${VERSION} installed!${NC}"
  echo ""
  echo "  Get started:"
  echo -e "    ${BLUE}octopus setup${NC}     Configure Octopus in the current repository"
  echo -e "    ${BLUE}octopus doctor${NC}    Verify installation health"
  echo -e "    ${BLUE}octopus --help${NC}    Show all available commands"
  echo ""
  echo "  Workflow commands (inside a configured repo):"
  echo "    octopus dev-flow          Guided development workflow"
  echo "    octopus pr-open           Open a pull request"
  echo "    octopus release           Create a versioned release"
  echo ""
  echo "  Docs: https://github.com/leocosta/octopus"
  echo ""
  echo "  Uninstall:"
  echo "    curl -fsSL https://github.com/leocosta/octopus/releases/latest/download/install.sh | bash -s -- --uninstall"
  echo ""
}

main "$@"
