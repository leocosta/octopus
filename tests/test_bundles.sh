#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLES_DIR="$SCRIPT_DIR/bundles"

echo "Test 1: all expected bundle files exist"
for name in starter quality-gates growth docs-discipline cross-stack dotnet-api node-api; do
  [[ -f "$BUNDLES_DIR/$name.yml" ]] \
    || { echo "FAIL: bundle $name.yml missing"; exit 1; }
done
echo "PASS: all seven bundles present"

echo "Test 2: every bundle has name/description/category"
for f in "$BUNDLES_DIR"/*.yml; do
  grep -q "^name: " "$f" || { echo "FAIL: $f missing 'name:'"; exit 1; }
  grep -q "^description: " "$f" || { echo "FAIL: $f missing 'description:'"; exit 1; }
  grep -qE "^category: (foundation|intent|stack)$" "$f" \
    || { echo "FAIL: $f missing valid 'category:'"; exit 1; }
done
echo "PASS: every bundle has required metadata"

echo "Test 3: intent and stack bundles all have persona_question"
for f in "$BUNDLES_DIR"/*.yml; do
  cat=$(awk '/^category: /{print $2; exit}' "$f")
  if [[ "$cat" == "intent" || "$cat" == "stack" ]]; then
    grep -q "^persona_question: " "$f" \
      || { echo "FAIL: $f ($cat) missing persona_question"; exit 1; }
  fi
done
echo "PASS: intent/stack bundles expose a persona question"

echo "All bundle structural tests passed!"

echo "Test 4: parse_octopus_yml accepts a bundles: list"

source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
cat > "$TMPDIR/test.yml" <<'EOF'
bundles:
  - starter
  - quality-gates
EOF

parse_octopus_yml "$TMPDIR/test.yml"

[[ ${#OCTOPUS_BUNDLES[@]} -eq 2 ]] \
  || { echo "FAIL: expected 2 bundles, got ${#OCTOPUS_BUNDLES[@]}"; exit 1; }
[[ "${OCTOPUS_BUNDLES[0]}" == "starter" ]] \
  || { echo "FAIL: first bundle wrong"; exit 1; }
[[ "${OCTOPUS_BUNDLES[1]}" == "quality-gates" ]] \
  || { echo "FAIL: second bundle wrong"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: parser reads bundles: list"
