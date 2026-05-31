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

# `_`-prefixed artifacts (_shared/, _base.md) are templates/fragments, not
# documentable artifacts — never scaffold them.
is_internal() { [[ "$1" == _* ]]; }

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
  | sed -E 's/^"//; s/"$//; s/^\(Octopus\) //; s/\(?RM-[0-9]+\)?//g; s/Cluster [0-9]+//g; s/\(#[0-9]+\)//g; s/shipped in v[0-9.]+//g; s/[[:space:]]+/ /g; s/^ //; s/ $//'
}

# A bundle's skills + roles, one `- name` per line (mechanical, from the .yml).
pull_bundle_members() {
  awk '
    /^(skills|roles):/ { s=1; next }
    /^[a-z_]+:/ { s=0 }
    s && /^[[:space:]]*-/ { sub(/#.*/, ""); gsub(/^[[:space:]]*-[[:space:]]*/, ""); gsub(/[[:space:]]+$/, ""); if ($0) print "- `" $0 "`" }
  ' "$1"
}

# The fenced code block under a command's `## Usage` heading (fences included),
# or empty when absent.
pull_usage_block() {
  awk '/^## Usage/{u=1; next} u && /^```/{f++; print; if (f==2) exit; next} u && f==1{print}' "$1"
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
    name="$(basename "$dir")"; is_internal "$name" && continue
    desc="$(pull_description "$dir/SKILL.md")"
    for prefix in "" "pt-br/"; do
      local dest="$DOCS/${prefix}skills/$name.mdx"
      [[ -f "$dest" ]] && continue          # idempotent: never touch an existing page
      write_skill_page "$name" "$desc" "$dest"
      echo "scaffold: created ${prefix}skills/$name.mdx" >&2
    done
  done
}

write_command_page() {  # <name> <description> <usage-block> <dest>
  local name="$1" desc="$2" usage="$3" dest="$4"
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
    echo "<!-- TODO: the concrete pain this command removes -->"
    echo
    echo "## How it works"
    echo
    echo "<!-- TODO: the mechanism -->"
    echo
    echo "## Usage & parameters"
    echo
    if [[ -n "$usage" ]]; then
      printf '%s\n' "$usage"
      echo
      echo "<!-- TODO: one row per flag/arg — what it does → default -->"
    else
      echo "<!-- TODO: invocation + parameters (flag → what it does → default) -->"
    fi
  } > "$dest"
}

scaffold_commands() {
  local f name desc usage
  for f in "$REPO"/commands/*.md; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .md)"; is_internal "$name" && continue
    desc="$(pull_description "$f")"
    usage="$(pull_usage_block "$f")"
    for prefix in "" "pt-br/"; do
      local dest="$DOCS/${prefix}commands/$name.mdx"
      [[ -f "$dest" ]] && continue
      write_command_page "$name" "$desc" "$usage" "$dest"
      echo "scaffold: created ${prefix}commands/$name.mdx" >&2
    done
  done
}

write_role_page() {  # <name> <description> <dest>
  local name="$1" desc="$2" dest="$3"
  mkdir -p "$(dirname "$dest")"
  {
    echo "---"; echo "title: $name"; echo "description: $desc"; echo "draft: true"; echo "---"; echo
    echo "<!-- TODO: Introduction — the hook (1–2 sentences) -->"; echo
    echo "## What it solves"; echo; echo "<!-- TODO: the concrete pain this role addresses -->"; echo
    echo "## How it works"; echo; echo "<!-- TODO: the mechanism -->"; echo
    echo "## When to invoke"; echo; echo "<!-- TODO: the situations this role is for -->"; echo
    echo "## What it judges"; echo; echo "<!-- TODO: what the role produces / the verdict it gives -->"
  } > "$dest"
}

write_bundle_page() {  # <name> <description> <members> <dest>
  local name="$1" desc="$2" members="$3" dest="$4"
  mkdir -p "$(dirname "$dest")"
  {
    echo "---"; echo "title: $name"; echo "description: $desc"; echo "draft: true"; echo "---"; echo
    echo "<!-- TODO: Introduction — the hook (1–2 sentences) -->"; echo
    echo "## What it solves"; echo; echo "<!-- TODO: the concrete pain enabling this bundle removes -->"; echo
    echo "## How it works"; echo; echo "<!-- TODO: the mechanism -->"; echo
    echo "## What's included"; echo; printf '%s\n' "$members"; echo
    echo "## When to enable"; echo; echo "<!-- TODO: the team/situation this bundle is for -->"
  } > "$dest"
}

scaffold_roles() {
  local f name desc
  for f in "$REPO"/roles/*.md; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .md)"; is_internal "$name" && continue; desc="$(pull_description "$f")"
    for prefix in "" "pt-br/"; do
      local dest="$DOCS/${prefix}roles/$name.mdx"; [[ -f "$dest" ]] && continue
      write_role_page "$name" "$desc" "$dest"; echo "scaffold: created ${prefix}roles/$name.mdx" >&2
    done
  done
}

scaffold_bundles() {
  local f name desc members
  for f in "$REPO"/bundles/*.yml; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .yml)"; is_internal "$name" && continue; desc="$(pull_description "$f")"; members="$(pull_bundle_members "$f")"
    for prefix in "" "pt-br/"; do
      local dest="$DOCS/${prefix}bundles/$name.mdx"; [[ -f "$dest" ]] && continue
      write_bundle_page "$name" "$desc" "$members" "$dest"; echo "scaffold: created ${prefix}bundles/$name.mdx" >&2
    done
  done
}

case "${1:-}" in
  skills)   scaffold_skills ;;
  commands) scaffold_commands ;;
  roles)    scaffold_roles ;;
  bundles)  scaffold_bundles ;;
  *) echo "usage: scaffold-docs.sh <skills|commands|roles|bundles>" >&2; exit 1 ;;
esac
