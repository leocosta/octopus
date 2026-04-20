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
NO_SHIM_SETUP=false

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
    --no-shim-setup)
      NO_SHIM_SETUP=true
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
      echo "  install.sh --no-shim-setup    Download release without touching the shim (used by the CLI when backfilling a version)"
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
    # Integrity check: compare the marker written at previous extraction
    # against the freshly-downloaded release checksum. Stale/corrupted
    # cache dirs (e.g. created by aborted downloads or older installers)
    # are purged and re-extracted instead of silently reused.
    local marker="$dest/.cache-sha256"
    local checksum_url
    checksum_url="$(resolve_checksum_url "$version")"
    if [[ -f "$marker" && -n "$checksum_url" ]]; then
      local tmp_sha
      tmp_sha="$(mktemp)"
      if curl -fsSL "$checksum_url" -o "$tmp_sha" 2>/dev/null; then
        local fresh_sha cached_sha
        fresh_sha="$(awk '{print $1}' "$tmp_sha")"
        cached_sha="$(cat "$marker" 2>/dev/null || echo '')"
        rm -f "$tmp_sha"
        if [[ -n "$fresh_sha" && "$fresh_sha" == "$cached_sha" ]]; then
          info "Octopus $version already cached at $dest (integrity OK)"
          DOWNLOADED_CHECKSUM="$cached_sha"
          return 0
        fi
        info "Cache integrity check failed for $version — re-downloading."
      else
        rm -f "$tmp_sha"
        # No checksum endpoint available; trust the cache to avoid breaking
        # offline re-installs. Uses the legacy "dir exists → reuse" path.
        info "Octopus $version already cached at $dest (no checksum endpoint)"
        return 0
      fi
    elif [[ ! -f "$marker" ]]; then
      info "Cache for $version has no integrity marker — re-downloading."
    else
      info "Octopus $version already cached at $dest"
      return 0
    fi
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

  # Write integrity marker so future runs can detect stale caches.
  printf '%s\n' "$DOWNLOADED_CHECKSUM" > "$dest/.cache-sha256"

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

# Install the shim — copies bin/octopus from the extracted release tree.
# Previously this function embedded the shim via a HEREDOC, duplicating
# ~240 lines of bin/octopus and creating a drift risk. See RM-019.
install_shim() {
  local version="$1"
  local source_shim="$OCTOPUS_CACHE_DIR/cache/$version/bin/octopus"

  if [[ ! -f "$source_shim" ]]; then
    error "Shim not found in extracted release at $source_shim"
    exit 1
  fi

  mkdir -p "$OCTOPUS_BIN_DIR"
  cp "$source_shim" "$OCTOPUS_BIN_DIR/octopus"
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

  # Install shim (copied from the downloaded release tree — see RM-019).
  # Skipped when invoked by the CLI shim itself to backfill a different version
  # without clobbering the currently-running binary.
  if [[ "$NO_SHIM_SETUP" != true ]]; then
    install_shim "$VERSION"
    check_path
  fi

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
