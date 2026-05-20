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
features_dir="$project_root/docs/features"
mkdir -p "$content_dir/commands" "$content_dir/skills"

# Hooks section ships hand-curated MDX under docs/site/hooks/ (v1.55.0+).
# No sync from docs/features/ — rsync above already copied them in.

generate_page "$features_dir/commands.md" "$content_dir/commands/index.md" \
  "Commands" "Slash commands installed by Octopus."

generate_page "$features_dir/skills.md" "$content_dir/skills/index.md" \
  "Skills" "Reusable AI capabilities organised by intent."

# Per-skill / per-concept rationale pages. Title is derived from the source
# file's H1 when present; falls back to the slug.
declare -A SKILL_TITLES=(
  [audit-all]="Audit all"
  [audit-money]="Audit money"
  [audit-tenant]="Audit tenant"
  [cross-stack-contract]="Cross-stack contract"
  [debug]="Debug"
  [feature-lifecycle]="Feature lifecycle"
  [feature-to-market]="Feature to market"
  [implement]="Implement"
  [plan-backlog]="Plan backlog hygiene"
  [release-announce]="Release announce"
  [review-pr]="Review PR"
)
for slug in "${!SKILL_TITLES[@]}"; do
  generate_page "$features_dir/$slug.md" "$content_dir/skills/$slug.md" \
    "${SKILL_TITLES[$slug]}" "Rationale and usage for the $slug skill."
done

echo "sync-content: linked $(ls -1 "$content_dir" | wc -l) entries under $content_dir"
