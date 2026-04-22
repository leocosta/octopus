# Lazy Skill Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `triggers:` frontmatter field to `SKILL.md` files so that `octopus setup` can replace non-matching skills with a 3-line stub in concatenated agent outputs, reducing output size by ≥ 40% for typical projects.

**Architecture:** Trigger evaluation runs in `setup.sh` via three new helpers (`_skill_has_triggers`, `_skill_triggers_match`, `_skill_triggers_summary`) that parse the SKILL.md frontmatter with python3 and evaluate path patterns, keywords, and tool names against the current project. `concatenate_from_manifest` gains a conditional branch: skills with unmatched triggers emit a 3-line stub; all others (including skills without `triggers:`) emit full content as today. Six existing skills gain `triggers:` frontmatter entries.

**Tech Stack:** Pure bash + python3 (already in `setup.sh`), no new external dependencies.

**Spec:** `docs/specs/lazy-skill-activation.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `setup.sh` | modify | Add trigger parser helpers + conditional stub logic in `concatenate_from_manifest` |
| `skills/e2e-testing/SKILL.md` | modify | Add `triggers:` frontmatter |
| `skills/dotnet/SKILL.md` | modify | Add `triggers:` frontmatter |
| `skills/security-scan/SKILL.md` | modify | Add `triggers:` frontmatter |
| `skills/money-review/SKILL.md` | modify | Add `triggers:` frontmatter |
| `skills/tenant-scope-audit/SKILL.md` | modify | Add `triggers:` frontmatter |
| `skills/cross-stack-contract/SKILL.md` | modify | Add `triggers:` frontmatter |
| `tests/test_lazy_skill_activation.sh` | create | Structural + integration tests for stub vs. full-content logic |

---

## Task 1: Trigger parser helpers + concatenate_from_manifest update

**Files:**
- Modify: `setup.sh`
- Create: `tests/test_lazy_skill_activation.sh`

- [x] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/test_lazy_skill_activation.sh
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Fixture: skill WITH triggers
mkdir -p "$TMPDIR_TEST/skills/triggered"
cat > "$TMPDIR_TEST/skills/triggered/SKILL.md" << 'EOF'
---
name: triggered
description: test
triggers:
  paths: ["**/*.spec.ts"]
  keywords: ["e2e", "cypress"]
  tools: []
---
# triggered skill body
EOF

# Fixture: skill WITHOUT triggers
mkdir -p "$TMPDIR_TEST/skills/always-on"
cat > "$TMPDIR_TEST/skills/always-on/SKILL.md" << 'EOF'
---
name: always-on
description: test
---
# always-on skill body
EOF

# Source helpers from setup.sh
# shellcheck disable=SC1090
source "$OCTOPUS_DIR/setup.sh" 2>/dev/null || true

echo "Test 1: _skill_has_triggers detects triggers: key"
OCTOPUS_DIR="$TMPDIR_TEST" _skill_has_triggers "triggered" \
  || { echo "FAIL: _skill_has_triggers should return 0 for skill with triggers:"; exit 1; }
echo "PASS"

echo "Test 2: _skill_has_triggers returns 1 for skill without triggers:"
OCTOPUS_DIR="$TMPDIR_TEST" _skill_has_triggers "always-on" \
  && { echo "FAIL: _skill_has_triggers should return 1 for skill without triggers:"; exit 1; }
echo "PASS"

echo "Test 3: skill with unmatched path triggers → _skill_triggers_match returns 1"
_OCTOPUS_GIT_FILES=""
OCTOPUS_DIR="$TMPDIR_TEST" _skill_triggers_match "triggered" \
  && { echo "FAIL: triggers should not match empty project"; exit 1; }
echo "PASS"

echo "Test 4: skill without triggers → _skill_has_triggers returns 1 (always full)"
OCTOPUS_DIR="$TMPDIR_TEST" _skill_has_triggers "always-on" \
  && { echo "FAIL: always-on should have no triggers:"; exit 1; }
echo "PASS (no triggers: → always full)"

echo "Test 5: skill with matching keyword → _skill_triggers_match returns 0"
FAKE_PROJ=$(mktemp -d)
echo "cypress end-to-end tests" > "$FAKE_PROJ/README.md"
_OCTOPUS_GIT_FILES=""
(
  cd "$FAKE_PROJ"
  OCTOPUS_DIR="$TMPDIR_TEST" \
    bash -c 'source "$1/setup.sh" 2>/dev/null || true
             _skill_triggers_match "triggered" \
               || { echo "FAIL: triggered should match keyword cypress in README"; exit 1; }
             echo "PASS"' _ "$OCTOPUS_DIR"
)
rm -rf "$FAKE_PROJ"
```

Run: `bash tests/test_lazy_skill_activation.sh`
Expected: FAIL — `_skill_has_triggers: command not found`

- [x] **Step 2: Run test to verify it fails**

Run: `bash tests/test_lazy_skill_activation.sh 2>&1 | head -5`
Expected: FAIL with function not found or sourcing error

- [x] **Step 3: Add helpers to setup.sh**

Add the following block immediately before `concatenate_from_manifest()`:

```bash
# Cache git-tracked files once (used by _skill_triggers_match)
_OCTOPUS_GIT_FILES=""
if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  _OCTOPUS_GIT_FILES=$(git ls-files)
fi

_skill_has_triggers() {
  local skill_file="$OCTOPUS_DIR/skills/${1}/SKILL.md"
  grep -q "^triggers:" "$skill_file" 2>/dev/null
}

_skill_triggers_match() {
  local skill_name="$1"
  local skill_file="$OCTOPUS_DIR/skills/${skill_name}/SKILL.md"

  local paths_raw keywords_raw tools_raw
  paths_raw=$(python3 - "$skill_file" <<'PYEOF'
import sys, re
content = open(sys.argv[1]).read()
m = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
if not m: sys.exit(0)
fm = m.group(1)
tm = re.search(r'triggers:\s*\n((?:\s+\S.*\n)*)', fm)
if not tm: sys.exit(0)
pm = re.search(r'paths:\s*\[([^\]]*)\]', tm.group(0))
if pm:
    items = [x.strip().strip('"\'') for x in pm.group(1).split(',') if x.strip()]
    print('\n'.join(items))
PYEOF
)
  keywords_raw=$(python3 - "$skill_file" <<'PYEOF'
import sys, re
content = open(sys.argv[1]).read()
m = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
if not m: sys.exit(0)
fm = m.group(1)
tm = re.search(r'triggers:\s*\n((?:\s+\S.*\n)*)', fm)
if not tm: sys.exit(0)
km = re.search(r'keywords:\s*\[([^\]]*)\]', tm.group(0))
if km:
    items = [x.strip().strip('"\'') for x in km.group(1).split(',') if x.strip()]
    print('\n'.join(items))
PYEOF
)
  tools_raw=$(python3 - "$skill_file" <<'PYEOF'
import sys, re
content = open(sys.argv[1]).read()
m = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
if not m: sys.exit(0)
fm = m.group(1)
tm = re.search(r'triggers:\s*\n((?:\s+\S.*\n)*)', fm)
if not tm: sys.exit(0)
tl = re.search(r'tools:\s*\[([^\]]*)\]', tm.group(0))
if tl:
    items = [x.strip().strip('"\'') for x in tl.group(1).split(',') if x.strip()]
    print('\n'.join(items))
PYEOF
)

  # paths: glob → ERE, match against cached git ls-files
  while IFS= read -r pat; do
    [[ -z "$pat" ]] && continue
    local regex
    regex=$(echo "$pat" | sed \
      's/\./\\./g;
       s/\*\*/DSTAR/g;
       s/\*/[^\/]*/g;
       s/DSTAR/.*/g')
    echo "$_OCTOPUS_GIT_FILES" | grep -qE "$regex" && return 0
  done <<< "$paths_raw"

  # keywords: grep in project root files and docs/
  while IFS= read -r kw; do
    [[ -z "$kw" ]] && continue
    grep -rqiE "$kw" README* package.json pyproject.toml docs/ 2>/dev/null && return 0
  done <<< "$keywords_raw"

  # tools: match against OCTOPUS_MANIFEST_TOOLS array
  while IFS= read -r tool; do
    [[ -z "$tool" ]] && continue
    [[ " ${OCTOPUS_MANIFEST_TOOLS[*]:-} " == *" $tool "* ]] && return 0
  done <<< "$tools_raw"

  return 1
}

_skill_triggers_summary() {
  local skill_file="$OCTOPUS_DIR/skills/${1}/SKILL.md"
  python3 - "$skill_file" <<'PYEOF'
import sys, re
content = open(sys.argv[1]).read()
m = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
if not m: print("configured triggers"); sys.exit(0)
fm = m.group(1)
tm = re.search(r'triggers:\s*\n((?:\s+\S.*\n)*)', fm)
if not tm: print("configured triggers"); sys.exit(0)
parts = []
pm = re.search(r'paths:\s*\[([^\]]*)\]', tm.group(0))
if pm:
    items = [x.strip().strip('"\'') for x in pm.group(1).split(',') if x.strip()]
    if items: parts.append("paths matching " + ", ".join(items))
km = re.search(r'keywords:\s*\[([^\]]*)\]', tm.group(0))
if km:
    items = [x.strip().strip('"\'') for x in km.group(1).split(',') if x.strip()]
    if items: parts.append("keywords: " + ", ".join(items))
tl = re.search(r'tools:\s*\[([^\]]*)\]', tm.group(0))
if tl:
    items = [x.strip().strip('"\'') for x in tl.group(1).split(',') if x.strip()]
    if items: parts.append("tools: " + ", ".join(items))
print("; ".join(parts) if parts else "configured triggers")
PYEOF
}
```

- [x] **Step 4: Update concatenate_from_manifest skills loop**

Replace the existing skills loop inside `concatenate_from_manifest`:

```bash
# Before
for skill in "${OCTOPUS_SKILLS[@]}"; do
  local skill_file="$OCTOPUS_DIR/skills/$skill/SKILL.md"
  if [[ -f "$skill_file" ]]; then
    echo "" >> "$full_output"
    cat "$skill_file" >> "$full_output"
  fi
done

# After
for skill in "${OCTOPUS_SKILLS[@]}"; do
  local skill_file="$OCTOPUS_DIR/skills/$skill/SKILL.md"
  [[ -f "$skill_file" ]] || continue
  if _skill_has_triggers "$skill" && ! _skill_triggers_match "$skill"; then
    local summary
    summary=$(_skill_triggers_summary "$skill")
    {
      echo ""
      echo "# ${skill} (inactive — triggers not matched at setup)"
      echo "Activate when: ${summary}."
      echo "Full protocol: read \`octopus/skills/${skill}/SKILL.md\` if conditions arise."
    } >> "$full_output"
  else
    echo "" >> "$full_output"
    cat "$skill_file" >> "$full_output"
  fi
done
```

- [x] **Step 5: Run test to verify it passes**

Run: `bash tests/test_lazy_skill_activation.sh`
Expected: PASS (all 5 tests)

- [x] **Step 6: Commit**

```bash
git add setup.sh tests/test_lazy_skill_activation.sh
git commit -m "feat(setup): lazy skill activation via triggers: frontmatter"
```

---

## Task 2: Add triggers: to path-based skills

**Files:**
- Modify: `skills/e2e-testing/SKILL.md`
- Modify: `skills/dotnet/SKILL.md`
- Modify: `skills/cross-stack-contract/SKILL.md`

- [x] **Step 1: Write the failing test**

Append to `tests/test_lazy_skill_activation.sh`:

```bash
echo "Test 6: e2e-testing has triggers: with paths"
grep -q "^triggers:" "$OCTOPUS_DIR/skills/e2e-testing/SKILL.md" \
  || { echo "FAIL: e2e-testing missing triggers:"; exit 1; }
grep -q 'spec.ts\|cypress\|playwright' "$OCTOPUS_DIR/skills/e2e-testing/SKILL.md" \
  || { echo "FAIL: e2e-testing triggers missing expected paths"; exit 1; }
echo "PASS"

echo "Test 7: dotnet has triggers: with paths"
grep -q "^triggers:" "$OCTOPUS_DIR/skills/dotnet/SKILL.md" \
  || { echo "FAIL: dotnet missing triggers:"; exit 1; }
grep -q '\.csproj\|\.cs' "$OCTOPUS_DIR/skills/dotnet/SKILL.md" \
  || { echo "FAIL: dotnet triggers missing expected paths"; exit 1; }
echo "PASS"

echo "Test 8: cross-stack-contract has triggers: with paths"
grep -q "^triggers:" "$OCTOPUS_DIR/skills/cross-stack-contract/SKILL.md" \
  || { echo "FAIL: cross-stack-contract missing triggers:"; exit 1; }
grep -q 'openapi\|contracts' "$OCTOPUS_DIR/skills/cross-stack-contract/SKILL.md" \
  || { echo "FAIL: cross-stack-contract triggers missing expected paths"; exit 1; }
echo "PASS"
```

Run: `bash tests/test_lazy_skill_activation.sh`
Expected: FAIL on Tests 6–8

- [x] **Step 2: Run to verify it fails**

Run: `bash tests/test_lazy_skill_activation.sh 2>&1 | grep -E "FAIL|Test [678]"`
Expected: FAIL on Tests 6, 7, 8

- [x] **Step 3: Add triggers: to the three skills**

In `skills/e2e-testing/SKILL.md`, insert after the `description:` block, before the closing `---`:

```yaml
triggers:
  paths: ["**/*.spec.ts", "**/*.spec.js", "**/*.test.ts", "cypress/**", "playwright/**"]
  keywords: []
  tools: []
```

In `skills/dotnet/SKILL.md`, insert after the `description:` block, before the closing `---`:

```yaml
triggers:
  paths: ["**/*.csproj", "**/*.cs", "**/*.sln", "**/*.fsproj"]
  keywords: []
  tools: []
```

In `skills/cross-stack-contract/SKILL.md`, insert after the `description:` block, before the closing `---`:

```yaml
triggers:
  paths: ["openapi/**", "contracts/**", "**/openapi.yaml", "**/openapi.json", "**/swagger.yaml"]
  keywords: []
  tools: []
```

- [x] **Step 4: Run to verify it passes**

Run: `bash tests/test_lazy_skill_activation.sh`
Expected: PASS (all tests including 6–8)

- [x] **Step 5: Commit**

```bash
git add skills/e2e-testing/SKILL.md skills/dotnet/SKILL.md skills/cross-stack-contract/SKILL.md
git commit -m "feat(skills): add path triggers to e2e-testing, dotnet, cross-stack-contract"
```

---

## Task 3: Add triggers: to keyword-based skills

**Files:**
- Modify: `skills/security-scan/SKILL.md`
- Modify: `skills/money-review/SKILL.md`
- Modify: `skills/tenant-scope-audit/SKILL.md`

- [x] **Step 1: Write the failing test**

Append to `tests/test_lazy_skill_activation.sh`:

```bash
echo "Test 9: security-scan has triggers: with keywords"
grep -q "^triggers:" "$OCTOPUS_DIR/skills/security-scan/SKILL.md" \
  || { echo "FAIL: security-scan missing triggers:"; exit 1; }
grep -q 'auth\|jwt\|secret\|token' "$OCTOPUS_DIR/skills/security-scan/SKILL.md" \
  || { echo "FAIL: security-scan triggers missing expected keywords"; exit 1; }
echo "PASS"

echo "Test 10: money-review has triggers: with keywords"
grep -q "^triggers:" "$OCTOPUS_DIR/skills/money-review/SKILL.md" \
  || { echo "FAIL: money-review missing triggers:"; exit 1; }
grep -q 'payment\|stripe\|billing\|invoice' "$OCTOPUS_DIR/skills/money-review/SKILL.md" \
  || { echo "FAIL: money-review triggers missing expected keywords"; exit 1; }
echo "PASS"

echo "Test 11: tenant-scope-audit has triggers: with keywords"
grep -q "^triggers:" "$OCTOPUS_DIR/skills/tenant-scope-audit/SKILL.md" \
  || { echo "FAIL: tenant-scope-audit missing triggers:"; exit 1; }
grep -q 'tenant\|org\|workspace' "$OCTOPUS_DIR/skills/tenant-scope-audit/SKILL.md" \
  || { echo "FAIL: tenant-scope-audit triggers missing expected keywords"; exit 1; }
echo "PASS"
```

Run: `bash tests/test_lazy_skill_activation.sh`
Expected: FAIL on Tests 9–11

- [x] **Step 2: Run to verify it fails**

Run: `bash tests/test_lazy_skill_activation.sh 2>&1 | grep -E "FAIL|Test (9|10|11)"`
Expected: FAIL on Tests 9, 10, 11

- [x] **Step 3: Add triggers: to the three skills**

In `skills/security-scan/SKILL.md`, insert after the `description:` block, before the closing `---`:

```yaml
triggers:
  paths: []
  keywords: ["auth", "jwt", "oauth", "secret", "token", "sql", "password", "credential"]
  tools: []
```

In `skills/money-review/SKILL.md`, insert after the `description:` block, before the closing `---`:

```yaml
triggers:
  paths: []
  keywords: ["payment", "invoice", "stripe", "billing", "subscription", "checkout", "price"]
  tools: []
```

In `skills/tenant-scope-audit/SKILL.md`, insert after the `description:` block, before the closing `---`:

```yaml
triggers:
  paths: []
  keywords: ["tenant", "org", "workspace", "multi-tenant", "organization"]
  tools: []
```

- [x] **Step 4: Run to verify it passes**

Run: `bash tests/test_lazy_skill_activation.sh`
Expected: PASS (all 11 tests)

- [x] **Step 5: Commit**

```bash
git add skills/security-scan/SKILL.md skills/money-review/SKILL.md skills/tenant-scope-audit/SKILL.md
git commit -m "feat(skills): add keyword triggers to security-scan, money-review, tenant-scope-audit"
```

---

## Task 4: Dog-food and roadmap close

**Files:**
- Create: `docs/research/2026-04-22-lazy-skill-dogfood.md`
- Modify: `docs/roadmap.md`
- Modify: `docs/specs/lazy-skill-activation.md`

- [x] **Step 1: Capture baseline line count**

```bash
# Identify a concatenated agent output (e.g. Copilot or Gemini if configured)
# For this repo, check what agents are configured:
ls agents/ 2>/dev/null || echo "no agents dir"
# Count lines in the output file before setup
wc -l .claude/CLAUDE.md 2>/dev/null || echo "no CLAUDE.md (template mode — measure a concat agent instead)"
```

- [x] **Step 2: Run octopus setup and measure reduction**

```bash
octopus setup
wc -l .claude/CLAUDE.md
# Note which skills were stubbed (look for "inactive — triggers not matched")
grep "inactive" .claude/CLAUDE.md 2>/dev/null || echo "no stubs found (template mode agent)"
```

- [x] **Step 3: Write research doc at docs/research/2026-04-22-lazy-skill-dogfood.md**

Capture: skills stubbed vs. full, before/after line counts and % reduction, any parsing issues or false negatives, fixes applied.

- [x] **Step 4: Move RM-022 to Completed in docs/roadmap.md**

In the Backlog section, remove the RM-022 bullet. Add to the Completed table:

```
| RM-022 | Lazy skill activation via `triggers:` frontmatter — path/keyword/tool evaluation at setup time; non-matching skills replaced with 3-line stub in concatenated outputs | completed → [Spec](specs/lazy-skill-activation.md) | 2026-04-22 |
```

- [x] **Step 5: Flip spec Status**

In `docs/specs/lazy-skill-activation.md`, change:
```
| **Status** | Draft |
```
to:
```
| **Status** | Implemented (2026-04-22) |
```

- [x] **Step 6: Commit**

```bash
git add docs/research/2026-04-22-lazy-skill-dogfood.md docs/roadmap.md docs/specs/lazy-skill-activation.md
git commit -m "docs: lazy-skill-activation dog-food + RM-022 completed"
```
