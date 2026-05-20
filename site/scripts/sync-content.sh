#!/usr/bin/env bash
# Sync canonical Octopus docs into Starlight's content collection.
#
# Strategy:
# - `docs/site/**` is the canonical home for rationale pages — symlink
#   into `site/src/content/docs/` so Astro picks them up as content.
# - `images/cover.png` is copied into `site/public/` for the hero.
# - We never write into the canonical tree from here. Read-only on
#   `docs/`, `images/`, etc.
#
# Idempotent: running twice yields the same result.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
site_dir="$(dirname "$script_dir")"
project_root="$(dirname "$site_dir")"

content_dir="$site_dir/src/content/docs"
public_dir="$site_dir/public"

# Wipe & re-create the content/docs symlink target so deletions in
# docs/site/ propagate cleanly.
rm -rf "$content_dir"
mkdir -p "$content_dir"

# Hard-copy docs/site/* into src/content/docs/*. Symlinks break
# Vite/Rollup import resolution inside .md files (they look for
# node_modules relative to the file's real path, which is outside
# site/). Hard copy keeps the build deterministic.
#
# Source of truth stays in docs/site/ — src/content/docs/ is build
# scratch (gitignored). Use a content-changes file watcher in dev
# if you need hot reload.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$project_root/docs/site/" "$content_dir/"
else
  cp -R "$project_root/docs/site/." "$content_dir/"
fi

# Copy the brand assets.
mkdir -p "$public_dir"
cp -f "$project_root/images/cover.png" "$public_dir/cover.png"
cp -f "$project_root/images/logo.png" "$public_dir/logo.png"
cp -f "$project_root/images/cover-dark.png" "$public_dir/cover-dark.png"
cp -f "$project_root/images/cover-light.png" "$public_dir/cover-light.png"
cp -f "$project_root/images/logo-dark.png" "$public_dir/logo-dark.png"
cp -f "$project_root/images/logo-light.png" "$public_dir/logo-light.png"

# Generate roadmap & changelog MDX pages from the canonical sources at the
# repo root. They live outside docs/site/ because they're updated by tooling
# (release flow, /octopus:doc-research). Wrapping them with a Starlight
# frontmatter is enough to make them routable pages.
generate_page() {
  local src="$1" dest="$2" title="$3" description="$4"
  if [[ ! -f "$src" ]]; then
    echo "sync-content: skipped $dest (source $src not found)" >&2
    return
  fi
  # Strip the first H1 — Starlight renders title from frontmatter.
  local body
  body=$(awk 'BEGIN{skip=0} /^# /{ if(!skip){skip=1; next} } {print}' "$src")
  {
    echo "---"
    echo "title: $title"
    echo "description: $description"
    echo "tableOfContents:"
    echo "  maxHeadingLevel: 3"
    echo "---"
    echo
    printf '%s\n' "$body"
  } > "$dest"
}

generate_page \
  "$project_root/docs/roadmap.md" \
  "$content_dir/roadmap.md" \
  "Roadmap" \
  "Project backlog — ideas that need team discussion before becoming a spec."

generate_page \
  "$project_root/CHANGELOG.md" \
  "$content_dir/changelog.md" \
  "Changelog" \
  "All notable changes to Octopus, version by version."

# Section overviews + per-skill rationale, mirrored from docs/features/.
# docs/features/ is the legacy reference home — site sections re-render the
# same hand-written prose under sidebar-friendly paths. Update the source
# files, not the generated copies.
# Hooks (v1.55.0+), Commands (v1.56.0+), and Skills (v1.57.0+) ship hand-
# curated MDX under docs/site/<section>/ — no sync from docs/features/.

echo "sync-content: linked $(ls -1 "$content_dir" | wc -l) entries under $content_dir"
