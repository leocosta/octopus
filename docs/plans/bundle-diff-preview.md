# Bundle Diff Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a skill-impact table after the multiselect in Full-mode wizard — shows lines and estimated tokens per selected skill so users understand the cost before confirming.

**Architecture:** New helper `_skill_impact_table()` in `cli/lib/setup-wizard.sh` reads `wc -l` from each selected skill's SKILL.md, computes token estimate (~4 tokens/line), and prints a two-column table. Called from `_wizard_sub_skills()` after `_multiselect` closes. No other files change.

**Tech Stack:** Pure bash. Grep-based tests.

**Spec:** `docs/specs/bundles-setup.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `cli/lib/setup-wizard.sh` | modify | Add `_skill_impact_table()` + call in `_wizard_sub_skills()` |
| `tests/test_bundle_preview.sh` | create | Structural grep tests |

---

## Task 1: Skill impact table + tests

**Files:**
- Modify: `cli/lib/setup-wizard.sh`
- Create: `tests/test_bundle_preview.sh`

- [ ] **Step 1: Write failing tests**

```bash
#!/usr/bin/env bash
# tests/test_bundle_preview.sh
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

WIZARD="$OCTOPUS_DIR/cli/lib/setup-wizard.sh"

# T1: _skill_impact_table function exists
check "_skill_impact_table function defined" \
  grep -q "_skill_impact_table()" "$WIZARD"

# T2: function uses wc -l to count lines
check "_skill_impact_table uses wc -l" \
  grep -A20 "_skill_impact_table()" "$WIZARD" | grep -q "wc -l"

# T3: function computes token estimate
check "_skill_impact_table computes tokens" \
  grep -A20 "_skill_impact_table()" "$WIZARD" | grep -qE "tok|token|\* 4|\*4"

# T4: _wizard_sub_skills calls _skill_impact_table
check "_wizard_sub_skills calls _skill_impact_table" \
  grep -A30 "_wizard_sub_skills\(\)" "$WIZARD" | grep -q "_skill_impact_table"

# T5: table header contains Lines and Tokens columns
check "table header contains Lines" \
  grep -A30 "_skill_impact_table()" "$WIZARD" | grep -qi "lines"
check "table header contains Tokens" \
  grep -A30 "_skill_impact_table()" "$WIZARD" | grep -qi "tokens"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test_bundle_preview.sh`
Expected: all FAIL

- [ ] **Step 3: Add `_skill_impact_table()` to `cli/lib/setup-wizard.sh`**

Add before `_wizard_sub_skills()`:

```bash
# _skill_impact_table <skill_name...>
# Prints a table showing SKILL.md line count and ~token estimate per skill.
_skill_impact_table() {
  local skills=("$@")
  [[ ${#skills[@]} -eq 0 ]] && return 0

  local skills_dir
  skills_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/skills"

  printf "\n  %s\n" "$(_dim "Impact of selected skills:")"
  printf "  %-30s %8s %10s\n" "Skill" "Lines" "~Tokens"
  printf "  %s\n" "$(printf '─%.0s' {1..50})"

  local total_lines=0 total_tokens=0
  local skill lines tokens
  for skill in "${skills[@]}"; do
    local skill_file="$skills_dir/$skill/SKILL.md"
    if [[ -f "$skill_file" ]]; then
      lines=$(wc -l < "$skill_file")
    else
      lines=0
    fi
    tokens=$(( lines * 4 ))
    total_lines=$(( total_lines + lines ))
    total_tokens=$(( total_tokens + tokens ))
    printf "  %-30s %8d %10d\n" "$skill" "$lines" "$tokens"
  done

  printf "  %s\n" "$(printf '─%.0s' {1..50})"
  printf "  %-30s %8d %10d\n" "Total" "$total_lines" "$total_tokens"
  printf "\n"
}
```

- [ ] **Step 4: Call `_skill_impact_table` from `_wizard_sub_skills()`**

After the `_multiselect` call and before `WIZARD_SKILLS=("${WIZARD_SELECTED[@]}")`:

```bash
  _multiselect \
    "Select skills" \
    "adr · audit-all · ..." \
    items defaults

  _skill_impact_table "${WIZARD_SELECTED[@]}"

  WIZARD_SKILLS=("${WIZARD_SELECTED[@]}")
```

- [ ] **Step 5: Run all tests**

Run: `bash tests/test_bundle_preview.sh`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add cli/lib/setup-wizard.sh tests/test_bundle_preview.sh
git commit -m "feat(wizard): add skill impact table in Full-mode skill selection (RM-027)"
```
