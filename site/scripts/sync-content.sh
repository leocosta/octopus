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
# Vite/Rollup import resolution inside .mdx files (they look for
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

echo "sync-content: linked $(ls -1 "$content_dir" | wc -l) entries under $content_dir"
