#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_FILE="$SCRIPT_DIR/skills/doc-api/SKILL.md"
CMD_FILE="$SCRIPT_DIR/commands/doc-api.md"
BUNDLE_FILE="$SCRIPT_DIR/bundles/docs.yml"
SHARED_FMT="$SCRIPT_DIR/skills/_shared/audit-output-format.md"

echo "Test 1: SKILL.md exists with valid frontmatter"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
[[ -f "$SHARED_FMT" ]] || { echo "FAIL: shared audit-output-format.md missing"; exit 1; }
head -n 6 "$SKILL_FILE" | grep -q "^name: doc-api$" \
  || { echo "FAIL: frontmatter 'name: doc-api' missing"; exit 1; }
head -n 8 "$SKILL_FILE" | grep -q "^model: sonnet$" \
  || { echo "FAIL: frontmatter 'model: sonnet' missing"; exit 1; }
head -n 12 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: slash command exists and dispatches to the skill"
[[ -f "$CMD_FILE" ]] || { echo "FAIL: $CMD_FILE missing"; exit 1; }
head -n 5 "$CMD_FILE" | grep -q "^name: doc-api$" \
  || { echo "FAIL: command frontmatter 'name: doc-api' missing"; exit 1; }
grep -q "skills/doc-api/SKILL.md" "$CMD_FILE" \
  || { echo "FAIL: command does not dispatch to the skill"; exit 1; }
echo "PASS: slash command present"

echo "Test 3: registered in the docs bundle"
grep -q "^  - doc-api$" "$BUNDLE_FILE" \
  || { echo "FAIL: doc-api not registered in bundles/docs.yml"; exit 1; }
echo "PASS: bundle registration present"

echo "Test 4: invocation, modes, and pipeline documented"
grep -q "^## Invocation$" "$SKILL_FILE" || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:doc-api" "$SKILL_FILE" || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--write" "--only" "--stacks" "--spec" "--out" "--base"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag missing"; exit 1; }
done
grep -q "^## Pipeline$" "$SKILL_FILE" || { echo "FAIL: '## Pipeline' missing"; exit 1; }
for stage in "Discover" "Extract" "Validate" "Document"; do
  grep -q "$stage" "$SKILL_FILE" || { echo "FAIL: pipeline stage '$stage' missing"; exit 1; }
done
echo "PASS: invocation + pipeline documented"

echo "Test 5: API version detection documented + patterns template present"
grep -q "^## API Version Detection$" "$SKILL_FILE" \
  || { echo "FAIL: '## API Version Detection' missing"; exit 1; }
for scheme in "Route-explicit" "Header" "Query" "Unversioned"; do
  grep -q "$scheme" "$SKILL_FILE" || { echo "FAIL: version scheme '$scheme' missing"; exit 1; }
done
grep -q "per version" "$SKILL_FILE" || { echo "FAIL: per-version scoping rule missing"; exit 1; }
TEMPLATE="$SCRIPT_DIR/skills/doc-api/templates/patterns.md"
[[ -f "$TEMPLATE" ]] || { echo "FAIL: templates/patterns.md missing"; exit 1; }
for stack in ".NET" "Node"; do
  grep -q "$stack" "$TEMPLATE" || { echo "FAIL: pattern stack '$stack' missing"; exit 1; }
done
echo "PASS: version detection + patterns documented"

echo "Test 6: four checks documented with severities + per-version breaking"
grep -q "^## Checks$" "$SKILL_FILE" || { echo "FAIL: '## Checks' missing"; exit 1; }
for check in "openapi" "errors" "breaking" "grounding"; do
  grep -q "\`$check\`" "$SKILL_FILE" || { echo "FAIL: check '$check' missing"; exit 1; }
done
grep -q "audit-grounding" "$SKILL_FILE" \
  || { echo "FAIL: grounding must reuse audit-grounding protocol"; exit 1; }
grep -q "per version" "$SKILL_FILE" || { echo "FAIL: per-version breaking rule missing"; exit 1; }
for sev in "🚫 Block" "⚠ Warn"; do
  grep -q -- "$sev" "$SKILL_FILE" || { echo "FAIL: severity '$sev' missing"; exit 1; }
done
echo "PASS: checks documented"

echo "Test 7: outputs, write gate, composition, errors documented"
for section in "## Outputs" "## Write Gate" "## Composition" "## Errors"; do
  grep -q "^$section$" "$SKILL_FILE" || { echo "FAIL: '$section' missing"; exit 1; }
done
# default + legacy autodetect paths
for path in "openapi.yaml" "docs/api/reference.md" "docs/openapi.yml" "docs/api-reference.md"; do
  grep -q "$path" "$SKILL_FILE" || { echo "FAIL: path '$path' missing"; exit 1; }
done
grep -q "docs/reviews/" "$SKILL_FILE" || { echo "FAIL: report path missing"; exit 1; }
# write gate confirms before writing and never touches code
grep -qi "confirm" "$SKILL_FILE" || { echo "FAIL: write-gate confirmation missing"; exit 1; }
grep -qi "never.*code\|only.*spec" "$SKILL_FILE" || { echo "FAIL: code-safety guarantee missing"; exit 1; }
# reuse of shared protocols
grep -q "_shared/audit-output-format.md" "$SKILL_FILE" || { echo "FAIL: shared output-format reuse missing"; exit 1; }
# English artifacts note
grep -qi "English" "$SKILL_FILE" || { echo "FAIL: English-artifact note missing"; exit 1; }
echo "PASS: outputs/gate/composition/errors documented"

echo "Test 8: SKILL.md within length budget"
LINES=$(wc -l < "$SKILL_FILE")
[[ "$LINES" -le 250 ]] || { echo "FAIL: SKILL.md is $LINES lines (> 250 cap)"; exit 1; }
echo "PASS: SKILL.md is $LINES lines"

echo "Test 9: Assess & Plan flow documented (correct / recreate / create per artifact)"
grep -q "^## Assess & Plan$" "$SKILL_FILE" || { echo "FAIL: '## Assess & Plan' section missing"; exit 1; }
grep -q "\*\*Assess\*\*" "$SKILL_FILE" || { echo "FAIL: Assess pipeline stage missing"; exit 1; }
for action in "correct" "recreate" "create" "skip"; do
  grep -q "\`$action\`" "$SKILL_FILE" || { echo "FAIL: action '$action' missing"; exit 1; }
done
for state in "absent" "stale" "ok"; do
  grep -q "\`$state\`" "$SKILL_FILE" || { echo "FAIL: artifact state '$state' missing"; exit 1; }
done
grep -qi "surgical patch" "$SKILL_FILE" || { echo "FAIL: correct=surgical-patch semantics missing"; exit 1; }
grep -qi "wholesale" "$SKILL_FILE" || { echo "FAIL: recreate=wholesale semantics missing"; exit 1; }
grep -q "first-class" "$SKILL_FILE" || { echo "FAIL: create first-class note missing"; exit 1; }
grep -q "Improvement Plan" "$SKILL_FILE" || { echo "FAIL: validate-mode plan preview missing"; exit 1; }
# breaking annotates the chosen action rather than being a state
grep -qi "annotates the chosen action\|annotates any action" "$SKILL_FILE" \
  || { echo "FAIL: breaking-change annotation missing"; exit 1; }
# write-only-chosen-items semantics in the gate
grep -qi "only the chosen items" "$SKILL_FILE" || { echo "FAIL: per-item write semantics missing"; exit 1; }
echo "PASS: Assess & Plan documented"
