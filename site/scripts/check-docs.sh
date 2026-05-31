#!/usr/bin/env bash
# site/scripts/check-docs.sh — deterministic guard for the public docs.
#
# Asserts that every PUBLISHED (non-draft) page under docs/site carries:
#   - no implementation leakage (RM-NNN / Cluster N / #NNN / "shipped in vX"),
#   - no unfinished `<!-- TODO -->` rationale.
#
# Zero LLM. Exits non-zero on findings, so it can gate CI. `--report` lists the
# findings and exits 0 — used during the transition while the sweep/scaffold
# slices close the existing gaps.
#
# Completeness (every artifact has an EN + pt-br page) is enforced by the
# scaffold slice, where the artifact↔page contract lives.
set -uo pipefail

DOCS_ROOT="${CHECK_DOCS_ROOT:-docs/site}"
REPO_ROOT="${CHECK_REPO_ROOT:-.}"
mode="check"; [[ "${1:-}" == "--report" ]] && mode="report"

# PR refs are matched only in their unambiguous forms — `(#123)` / `PR #123` —
# so hex colours like `#008000` in role frontmatter are not false positives.
leak_re='RM-[0-9]+|Cluster [0-9]+|\(#[0-9]+\)|PR #[0-9]+|shipped in v[0-9]'
todo_re='\{/\* TODO|<!-- TODO'
findings=0

# A page is a draft when its frontmatter (first `---` block) sets draft: true.
is_draft() {
  awk '/^---/{n++; next} n==1 && /^draft:[[:space:]]*true[[:space:]]*$/{f=1} n>=2{exit} END{exit !f}' "$1"
}

while IFS= read -r page; do
  is_draft "$page" && continue
  if grep -EnH "$leak_re" "$page" 2>/dev/null; then findings=$((findings + 1)); fi
  if grep -EnH "$todo_re" "$page" 2>/dev/null; then findings=$((findings + 1)); fi
done < <(find "$DOCS_ROOT" -type f \( -name '*.md' -o -name '*.mdx' \) | sort)

# Completeness: every documentable artifact must have an EN + pt-br page (draft
# or published). Mirrors scaffold-docs.sh's rules — `_`-prefixed items are
# templates, skills need a SKILL.md. Scoped to the types the generator covers;
# a collection is checked only when its source dir exists under REPO_ROOT.
require_pages() {  # <name> <collection>
  local name="$1" coll="$2" lang
  [[ "$name" == _* ]] && return 0
  for lang in "" "pt-br/"; do
    if [[ ! -f "$DOCS_ROOT/${lang}${coll}/$name.mdx" ]]; then
      echo "MISSING: ${lang}${coll}/$name.mdx"; findings=$((findings + 1))
    fi
  done
}
if [[ -d "$REPO_ROOT/skills" ]]; then
  for d in "$REPO_ROOT"/skills/*/; do [[ -f "$d/SKILL.md" ]] && require_pages "$(basename "$d")" skills; done
fi
[[ -d "$REPO_ROOT/commands" ]] && for f in "$REPO_ROOT"/commands/*.md;  do [[ -f "$f" ]] && require_pages "$(basename "$f" .md)"  commands; done
[[ -d "$REPO_ROOT/roles" ]]    && for f in "$REPO_ROOT"/roles/*.md;     do [[ -f "$f" ]] && require_pages "$(basename "$f" .md)"  roles;    done
[[ -d "$REPO_ROOT/bundles" ]]  && for f in "$REPO_ROOT"/bundles/*.yml;  do [[ -f "$f" ]] && require_pages "$(basename "$f" .yml)" bundles;  done

echo "----"
echo "check-docs: $findings finding(s) in published pages under $DOCS_ROOT"
[[ "$mode" == report ]] && exit 0
[[ "$findings" -eq 0 ]]
