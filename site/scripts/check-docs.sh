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
mode="check"; [[ "${1:-}" == "--report" ]] && mode="report"

leak_re='RM-[0-9]+|Cluster [0-9]+|#[0-9]{2,}|shipped in v[0-9]'
todo_re='<!-- TODO'
findings=0

# A page is a draft when its frontmatter (first `---` block) sets draft: true.
is_draft() {
  awk '/^---/{n++; next} n==1 && /^draft:[[:space:]]*true[[:space:]]*$/{f=1} n>=2{exit} END{exit !f}' "$1"
}

while IFS= read -r page; do
  is_draft "$page" && continue
  if grep -EnH "$leak_re" "$page" 2>/dev/null; then findings=$((findings + 1)); fi
  if grep -nH "$todo_re" "$page" 2>/dev/null; then findings=$((findings + 1)); fi
done < <(find "$DOCS_ROOT" -type f \( -name '*.md' -o -name '*.mdx' \) | sort)

echo "----"
echo "check-docs: $findings finding(s) in published pages under $DOCS_ROOT"
[[ "$mode" == report ]] && exit 0
[[ "$findings" -eq 0 ]]
