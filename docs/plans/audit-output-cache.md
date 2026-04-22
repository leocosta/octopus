# Audit Output Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a content-keyed cache layer to all four audit skills so that re-running the same audit on an unchanged diff costs zero LLM tokens.

**Architecture:** A new shared fragment `skills/_shared/audit-cache.md` defines a Check + Write protocol that composes with the existing `audit-pre-pass.md`. Cache key = `sha256(scoped_diff + SKILL.md content)`, stored at `.octopus/cache/<skill>/<key>.md` with YAML frontmatter. Each skill's discovery section gains one line referencing the cache fragment. No CLI changes.

**Tech Stack:** Pure markdown. Grep-based bash tests (project convention).

**Spec:** `docs/specs/audit-output-cache.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `skills/_shared/audit-cache.md` | create | Cache Check + Write protocol |
| `tests/test_audit_output_cache.sh` | create | Structural grep tests |
| `skills/money-review/SKILL.md` | modify | Add `audit-cache.md` reference in File Discovery |
| `skills/security-scan/SKILL.md` | modify | Add `audit-cache.md` reference in File Discovery |
| `skills/cross-stack-contract/SKILL.md` | modify | Add `audit-cache.md` reference in File Discovery |
| `skills/tenant-scope-audit/SKILL.md` | modify | Add `audit-cache.md` reference in File Discovery |

---

## Task 1: Shared fragment + test scaffolding

**Files:**
- Create: `skills/_shared/audit-cache.md`
- Create: `tests/test_audit_output_cache.sh`

- [ ] **Step 1: Write the failing tests**

```bash
#!/usr/bin/env bash
# tests/test_audit_output_cache.sh
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

# T1: shared fragment exists
check "shared fragment exists" \
  test -f "$OCTOPUS_DIR/skills/_shared/audit-cache.md"

# T2: fragment contains protocol markers
check "fragment contains 'Cache Check'" \
  grep -q "Cache Check" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains 'Cache Write'" \
  grep -q "Cache Write" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains 'CACHE_KEY'" \
  grep -q "CACHE_KEY" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains 'CACHE_FILE'" \
  grep -q "CACHE_FILE" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains 'sha256'" \
  grep -q "sha256" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains '.octopus/cache'" \
  grep -q ".octopus/cache" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains 'created_at'" \
  grep -q "created_at" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"

# T3: each skill references audit-cache.md
check "money-review references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/money-review/SKILL.md"
check "security-scan references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/security-scan/SKILL.md"
check "cross-stack-contract references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/cross-stack-contract/SKILL.md"
check "tenant-scope-audit references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/tenant-scope-audit/SKILL.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test_audit_output_cache.sh`
Expected: FAIL on T1 (fragment not found) and all downstream checks

- [ ] **Step 3: Create `skills/_shared/audit-cache.md`**

```markdown
# Audit Output Cache Protocol

## Cache Check (before LLM analysis)

Execute immediately after the Pre-Pass produces SCOPED_DIFF, before any inspection check.

**Step 1 — compute CACHE_KEY**

```bash
SKILL_HASH=$(sha256sum <path-to-this-SKILL.md> | cut -c1-64)
CACHE_KEY=$(echo -n "${SCOPED_DIFF}${SKILL_HASH}" | sha256sum | cut -c1-64)
```

**Step 2 — check for hit**

```
CACHE_FILE=.octopus/cache/<skill-name>/<CACHE_KEY>.md
```

If `CACHE_FILE` exists:
- Strip the YAML frontmatter (lines between the first `---` and the closing `---`)
- Print the body as-is
- Stop — do not proceed to inspection checks

**Step 3 — on miss: proceed**

Continue to inspection checks normally. After the LLM produces its full output, execute the Cache Write steps below before returning to the user.

## Cache Write (after LLM produces output)

**Step 4 — ensure directory exists**

Create `.octopus/cache/<skill-name>/` if it does not exist.

**Step 5 — write cache file**

Write `CACHE_FILE` with this structure:
```
---
skill: <skill-name>
ref: <ref argument>
base: <base branch>
created_at: <current UTC datetime in ISO 8601>
---

<full audit output exactly as printed to the user>
```

**Step 6 — .gitignore guard**

If `.octopus/cache/` is not present in the repo's `.gitignore`, append it.
Warn the user if `.gitignore` cannot be written; do not abort.
```

- [ ] **Step 4: Run tests to verify T1–T2 pass**

Run: `bash tests/test_audit_output_cache.sh`
Expected: T1–T2 PASS (8 checks); T3 still FAIL (skills not yet updated)

- [ ] **Step 5: Commit**

```bash
git add skills/_shared/audit-cache.md tests/test_audit_output_cache.sh
git commit -m "feat(audit): add shared cache protocol fragment and test scaffolding (RM-026)"
```

---

## Task 2: Wire cache protocol into all 4 audit skills

**Files:**
- Modify: `skills/money-review/SKILL.md`
- Modify: `skills/security-scan/SKILL.md`
- Modify: `skills/cross-stack-contract/SKILL.md`
- Modify: `skills/tenant-scope-audit/SKILL.md`

- [ ] **Step 1: Update all 4 skills**

In each skill's File Discovery section, add one line after the `audit-pre-pass.md` reference:

```markdown
## File Discovery

Follow the Pre-Pass protocol in `skills/_shared/audit-pre-pass.md`.
Use this skill's `pre_pass.file_patterns` and `pre_pass.line_patterns` from the frontmatter.
Then follow the Cache protocol in `skills/_shared/audit-cache.md` before proceeding to inspection checks.
```

Apply to:
- `skills/money-review/SKILL.md` → `## File Discovery`
- `skills/security-scan/SKILL.md` → `## File Discovery`
- `skills/cross-stack-contract/SKILL.md` → `## File Discovery`
- `skills/tenant-scope-audit/SKILL.md` → `## File Discovery`

- [ ] **Step 2: Run all tests**

Run: `bash tests/test_audit_output_cache.sh`
Expected: all 11 checks PASS (0 failures)

Also run the pre-pass tests to confirm no regressions:
Run: `bash tests/test_pre_llm_audit_pass.sh`
Expected: all 15 checks PASS

- [ ] **Step 3: Commit**

```bash
git add skills/money-review/SKILL.md skills/security-scan/SKILL.md \
        skills/cross-stack-contract/SKILL.md skills/tenant-scope-audit/SKILL.md
git commit -m "feat(audit): wire cache protocol into all 4 audit skills (RM-026)"
```
