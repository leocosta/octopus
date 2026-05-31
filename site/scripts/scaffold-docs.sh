#!/usr/bin/env bash
# site/scripts/scaffold-docs.sh — generate missing doc pages for Octopus
# artifacts. Permanent + idempotent: it creates a page only for an artifact
# with no doc yet (mechanical sections filled from the artifact, curated prose
# as `<!-- TODO -->`, `draft: true`), in EN and pt-br. It NEVER overwrites an
# existing page — curated rationale is hand-written and the generator must not
# touch it. The curation principle holds: only mechanical facts are generated.
#
# Usage: scaffold-docs.sh skills        # (more artifact types land incrementally)
set -euo pipefail

REPO="${SCAFFOLD_REPO_ROOT:-.}"
DOCS="${SCAFFOLD_DOCS_ROOT:-$REPO/docs/site}"

# Pull a YAML `description:` (plain or `>`-folded) from a SKILL.md, join it to a
# single line, and strip implementation leakage (RM-NNN / Cluster N / (#NNN) /
# shipped in vX) so the public page is born clean.
pull_description() {
  awk '
    /^description:/ { d=1; sub(/^description:[[:space:]]*>?[[:space:]]*/, ""); if ($0 != "") buf=$0; next }
    d && /^[a-z_]+:/ { d=0 }
    d && /^---/ { d=0 }
    d { gsub(/^[[:space:]]+/, ""); buf=(buf=="") ? $0 : buf " " $0 }
    END { print buf }
  ' "$1" \
  | sed -E 's/\(?RM-[0-9]+\)?//g; s/Cluster [0-9]+//g; s/\(#[0-9]+\)//g; s/shipped in v[0-9.]+//g; s/[[:space:]]+/ /g; s/^ //; s/ $//'
}

write_skill_page() {  # <name> <description> <dest>
  local name="$1" desc="$2" dest="$3"
  mkdir -p "$(dirname "$dest")"
  {
    echo "---"
    echo "title: $name"
    echo "description: $desc"
    echo "draft: true"
    echo "---"
    echo
    echo "<!-- TODO: Introduction — the hook (1–2 sentences) -->"
    echo
    echo "## What it solves"
    echo
    echo "<!-- TODO: the concrete pain this skill removes -->"
    echo
    echo "## How it works"
    echo
    echo "<!-- TODO: the mechanism -->"
    echo
    echo "## Usage"
    echo
    echo "<!-- TODO: invocation + parameters (flag → what it does → default) -->"
  } > "$dest"
}

scaffold_skills() {
  local dir name desc
  for dir in "$REPO"/skills/*/; do
    [[ -f "$dir/SKILL.md" ]] || continue
    name="$(basename "$dir")"
    desc="$(pull_description "$dir/SKILL.md")"
    for prefix in "" "pt-br/"; do
      local dest="$DOCS/${prefix}skills/$name.mdx"
      [[ -f "$dest" ]] && continue          # idempotent: never touch an existing page
      write_skill_page "$name" "$desc" "$dest"
      echo "scaffold: created ${prefix}skills/$name.mdx" >&2
    done
  done
}

case "${1:-}" in
  skills) scaffold_skills ;;
  *) echo "usage: scaffold-docs.sh skills" >&2; exit 1 ;;
esac
