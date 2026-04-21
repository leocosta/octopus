# cli/lib/release.sh — Release management subcommands
# Usage: octopus.sh release <subcommand> [args]

SUBCMD="${1:-}"
shift 2>/dev/null || true

if [[ -z "$SUBCMD" ]]; then
  echo "Usage: octopus.sh release <subcommand> [args]"
  echo ""
  echo "Subcommands:"
  echo "  suggest-version [from-ref]     Suggest next semver based on commits"
  echo "  list-commits [from-ref]        List commits since last tag"
  echo "  create-tag <version> <file>    Create annotated tag"
  echo "  commit-changelog <version>     Commit CHANGELOG.md"
  echo "  create-gh-release <ver> <file> Create GitHub Release"
  exit 1
fi

# Find the latest semver tag (anchored to exclude pre-release)
get_latest_tag() {
  local from_ref="${1:-}"
  if [[ -n "$from_ref" ]]; then
    echo "$from_ref"
    return
  fi
  local tag
  tag=$(git tag --sort=-v:refname 2>/dev/null | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
  echo "${tag:-}"
}

# Strip leading 'v' from version
strip_v() {
  echo "${1#v}"
}

sync_release_readme() {
  local version="${1:-}"
  local readme="README.md"

  if [[ -z "$version" ]]; then
    echo "Usage: sync_release_readme <version>"
    exit 1
  fi

  if [[ ! -f "$readme" ]]; then
    echo "README.md not found. Skipping README version sync."
    return 0
  fi

  python3 - "$readme" "$version" <<'PY'
import pathlib
import re
import sys

readme_path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
original = readme_path.read_text()
updated = original

patterns = [
    (
        "version badge",
        r'!\[Version\]\(https://img\.shields\.io/badge/version-v\d+\.\d+\.\d+-blue\)',
        f'![Version](https://img.shields.io/badge/version-{version}-blue)',
        '![Version](https://img.shields.io/badge/version-',
    ),
    (
        "manual update checkout command",
        r'cd octopus && git fetch --tags && git checkout v\d+\.\d+\.\d+ && cd \.\.',
        f'cd octopus && git fetch --tags && git checkout {version} && cd ..',
        'cd octopus && git fetch --tags && git checkout ',
    ),
    (
        "manual update commit example",
        r'git add octopus && git commit -m "chore: update octopus to v\d+\.\d+\.\d+"',
        f'git add octopus && git commit -m "chore: update octopus to {version}"',
        'git add octopus && git commit -m "chore: update octopus to ',
    ),
    (
        "install --version example",
        r'--version v\d+\.\d+\.\d+',
        f'--version {version}',
        '--version v',
    ),
]

errors = []

for label, pattern, replacement, anchor in patterns:
    if anchor not in updated:
        continue

    next_text, count = re.subn(pattern, replacement, updated)
    if count == 0:
        errors.append(label)
        continue
    updated = next_text

if errors:
    labels = ", ".join(errors)
    print(f"ERROR: README version sync failed for: {labels}", file=sys.stderr)
    sys.exit(1)

if updated != original:
    readme_path.write_text(updated)
    print(f"README.md version references updated for {version}.")
else:
    print(f"README.md version references already current for {version}.")
PY
}

case "$SUBCMD" in
  suggest-version)
    FROM_REF="${1:-}"
    LATEST_TAG=$(get_latest_tag "$FROM_REF")

    if [[ -z "$LATEST_TAG" ]]; then
      CURRENT="0.0.0"
      RANGE="HEAD"
    else
      CURRENT=$(strip_v "$LATEST_TAG")
      RANGE="${LATEST_TAG}..HEAD"
    fi

    # Check if there are commits
    COMMIT_COUNT=$(git rev-list --count "$RANGE" 2>/dev/null || echo "0")
    if [[ "$COMMIT_COUNT" -eq 0 ]]; then
      echo "No unreleased commits found."
      exit 0
    fi

    # Parse commits for bump level
    BUMP="patch"
    while IFS= read -r line; do
      # Check for BREAKING CHANGE or ! after type
      if echo "$line" | grep -qE '(BREAKING CHANGE|^[a-f0-9]+ [a-z]+(\([^)]*\))?!)'; then
        BUMP="major"
        break
      fi
      if echo "$line" | grep -qE '^[a-f0-9]+ feat'; then
        BUMP="minor"
      fi
    done < <(git log "$RANGE" --oneline --format="%H %s" 2>/dev/null)

    # Check commit bodies for BREAKING CHANGE
    if git log "$RANGE" --format="%b" 2>/dev/null | grep -q "BREAKING CHANGE"; then
      BUMP="major"
    fi

    # Calculate new version
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
    case "$BUMP" in
      major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
      minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
      patch) PATCH=$((PATCH + 1)) ;;
    esac

    echo "current=$CURRENT suggested=$MAJOR.$MINOR.$PATCH"
    ;;

  list-commits)
    FROM_REF="${1:-}"
    LATEST_TAG=$(get_latest_tag "$FROM_REF")

    if [[ -z "$LATEST_TAG" ]]; then
      RANGE=""
    else
      RANGE="${LATEST_TAG}..HEAD"
    fi

    COMMIT_COUNT=$(git rev-list --count ${RANGE:-HEAD} 2>/dev/null || echo "0")
    if [[ "$COMMIT_COUNT" -eq 0 ]]; then
      echo "No unreleased commits found."
      exit 0
    fi

    git log ${RANGE:-HEAD} --oneline
    ;;

  create-tag)
    VERSION="${1:-}"
    MSG_FILE="${2:-}"
    if [[ -z "$VERSION" || -z "$MSG_FILE" ]]; then
      echo "Usage: octopus.sh release create-tag <version> <message-file>"
      exit 1
    fi
    if [[ ! -f "$MSG_FILE" ]]; then
      echo "ERROR: Message file not found: $MSG_FILE"
      exit 1
    fi
    [[ "$VERSION" == v* ]] || VERSION="v$VERSION"
    git tag -a "$VERSION" -F "$MSG_FILE"
    echo "Tag $VERSION created."
    ;;

  commit-changelog)
    VERSION="${1:-}"
    if [[ -z "$VERSION" ]]; then
      echo "Usage: octopus.sh release commit-changelog <version>"
      exit 1
    fi
    [[ "$VERSION" == v* ]] || VERSION="v$VERSION"
    sync_release_readme "$VERSION"
    git add CHANGELOG.md
    if [[ -f README.md ]]; then
      git add README.md
    fi
    git commit -m "chore(release): $VERSION"
    echo "Release docs committed for $VERSION."
    ;;

  create-gh-release)
    VERSION="${1:-}"
    NOTES_FILE="${2:-}"
    if [[ -z "$VERSION" || -z "$NOTES_FILE" ]]; then
      echo "Usage: octopus.sh release create-gh-release <version> <notes-file>"
      exit 1
    fi
    if [[ ! -f "$NOTES_FILE" ]]; then
      echo "ERROR: Notes file not found: $NOTES_FILE"
      exit 1
    fi
    [[ "$VERSION" == v* ]] || VERSION="v$VERSION"
    gh release create "$VERSION" --notes-file "$NOTES_FILE"
    echo "GitHub Release $VERSION created."
    ;;

  *)
    echo "Unknown subcommand: $SUBCMD"
    echo "Run 'octopus.sh release' for usage."
    exit 1
    ;;
esac
