#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_ROOT="${OCTOPUS_CLI_CACHE_ROOT:-$HOME/.octopus-cli}"
CACHE_DIR="$CACHE_ROOT/cache"
BIN_DIR="${OCTOPUS_INSTALL_BIN:-$HOME/.local/bin}"
VERSION="${1:-}"
RELEASE_OWNER="${OCTOPUS_RELEASE_OWNER:-leocosta}"
RELEASE_NAME="${OCTOPUS_RELEASE_NAME:-octopus}"
INSTALL_ENDPOINT="${OCTOPUS_INSTALL_ENDPOINT:-https://github.com/$RELEASE_OWNER/$RELEASE_NAME/releases/download}"
API_ENDPOINT="${OCTOPUS_API_ENDPOINT:-https://api.github.com/repos/$RELEASE_OWNER/$RELEASE_NAME/releases/latest}"
TMP_DOWNLOAD_DIR=""
LATEST_CHECKSUM=""

ARCHIVE_NAME() { echo "octopus-$1.tar.gz"; }
CHECKSUM_NAME() { echo "octopus-$1.sha256"; }

resolve_latest_version() {
  local payload
  payload="$(curl -fsSL "$API_ENDPOINT" 2>/dev/null || true)"
  if [[ -n "$payload" ]]; then
    printf '%s' "$payload" | grep '"tag_name"' | head -n1 | sed -E 's/.*"([^"]+)".*/\1/'
  fi
}

usage() {
  cat <<EOF
Usage: install.sh [--version <tag>] [--bin-dir <path>] [--cache-root <path>]

Options:
  --version <tag>     Git tag or ref to install (default: latest tag)
  --bin-dir <path>    Directory to expose the global \`octopus\` shim (default: $BIN_DIR)
  --cache-root <path> Base directory for Octopus cache (default: \\$HOME/.octopus-cli)
EOF
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        VERSION="$2"
        shift 2
        ;;
      --bin-dir)
        BIN_DIR="$2"
        shift 2
        ;;
      --cache-root)
        CACHE_ROOT="$2"
        CACHE_DIR="$CACHE_ROOT/cache"
        shift 2
        ;;
      -h | --help)
        usage
        ;;
      *)
        usage
        ;;
    esac
  done
}

ensure_cache_dirs() {
  mkdir -p "$CACHE_DIR"
}

ensure_target_dir() {
  mkdir -p "$TARGET_DIR"
}

cleanup_download() {
  [[ -n "$TMP_DOWNLOAD_DIR" ]] && rm -rf "$TMP_DOWNLOAD_DIR"
  TMP_DOWNLOAD_DIR=""
}

download_release_tarball() {
  local version="$1"
  LATEST_CHECKSUM=""
  TMP_DOWNLOAD_DIR="$(mktemp -d)"
  local archive_path="$TMP_DOWNLOAD_DIR/$(ARCHIVE_NAME "$version")"
  local checksum_path="$TMP_DOWNLOAD_DIR/$(CHECKSUM_NAME "$version")"
  curl -fsSL "$INSTALL_ENDPOINT/$version/$(ARCHIVE_NAME "$version")" -o "$archive_path" || return 1
  curl -fsSL "$INSTALL_ENDPOINT/$version/$(CHECKSUM_NAME "$version")" -o "$checksum_path" || return 1
  verify_checksum "$archive_path" "$checksum_path"
  tar -xzf "$archive_path" -C "$TARGET_DIR" --strip-components=1
  cleanup_download
  return 0
}

verify_checksum() {
  local file="$1"
  local checksum_file="$2"
  local expected
  expected="$(awk '{print $1}' "$checksum_file")"
  local actual
  actual="$(sha256sum "$file" | awk '{print $1}')"
  if [[ "$expected" != "$actual" ]]; then
    echo "Checksum mismatch for $file" >&2
    echo "expected: $expected" >&2
    echo "actual:   $actual" >&2
    return 1
  fi
  LATEST_CHECKSUM="$expected"
}

prepare_cache_from_git() {
  if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    rm -rf "$TARGET_DIR"
    mkdir -p "$TARGET_DIR"
    git archive "$VERSION" | tar -x -C "$TARGET_DIR"
    return 0
  fi
  return 1
}

install_release() {
  local version="$1"
  ensure_cache_dirs
  ensure_target_dir
  rm -rf "$TARGET_DIR"/*
  if ! download_release_tarball "$version"; then
    prepare_cache_from_git || {
      echo "Failed to install release $version (no release asset and not in git repo)" >&2
      exit 1
    }
  fi
  [[ -x "$TARGET_DIR/bin/octopus" ]] || {
    mkdir -p "$TARGET_DIR/bin"
    cp "$SCRIPT_DIR/bin/octopus" "$TARGET_DIR/bin/octopus"
    chmod +x "$TARGET_DIR/bin/octopus"
  }
  local checksum
  checksum="${LATEST_CHECKSUM:-$(compute_local_checksum "$TARGET_DIR")}"
  write_metadata "$version" "$checksum"
  echo "Installed Octopus $version (cached at $TARGET_DIR)"
}

compute_local_checksum() {
  local root="$1"
  (cd "$root" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')
}

write_metadata() {
  local version="$1"
  local checksum="$2"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$CACHE_ROOT"
  cat > "$CACHE_ROOT/metadata.json" <<EOF
{
  "version": "$version",
  "checksum": "$checksum",
  "installed_at": "$timestamp",
  "release_endpoint": "$INSTALL_ENDPOINT"
}
EOF
}

parse_args "$@"
if [[ -z "$VERSION" ]]; then
  VERSION="$(resolve_latest_version)"
  if [[ -z "$VERSION" ]]; then
    if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      VERSION="$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null || git -C "$SCRIPT_DIR" rev-parse --short HEAD)"
    fi
  fi
fi
if [[ -z "$VERSION" ]]; then
  echo "Unable to determine Octopus release version" >&2
  exit 1
fi

TARGET_DIR="$CACHE_DIR/$VERSION"
SHIM_PATH="$BIN_DIR/octopus"

install_release "$VERSION"

mkdir -p "$BIN_DIR"
cat > "$SHIM_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CACHE_ROOT="${OCTOPUS_CLI_CACHE_ROOT:-$HOME/.octopus-cli}"
METADATA="$CACHE_ROOT/metadata.json"

if [[ ! -f "$METADATA" ]]; then
  echo "Octopus CLI metadata missing; run install.sh first" >&2
  exit 1
fi

version="$(grep -E '"version"[[:space:]]*:' "$METADATA" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"
exec "$CACHE_ROOT/cache/$version/bin/octopus" "$@"
EOF

chmod +x "$SHIM_PATH"

echo "Installed Octopus CLI $VERSION and created shim at $SHIM_PATH"
