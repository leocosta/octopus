# Pre-LLM Audit Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `pre_pass:` frontmatter and a shared fragment `audit-pre-pass.md` so the 4 audit skills deterministically filter relevant files before passing the diff to the LLM, enabling early-exit on PRs with no relevant changes.

**Architecture:** A new shared fragment `skills/_shared/audit-pre-pass.md` defines a 4-step protocol (candidate files → early exit → optional line filter → scoped diff output). Each audit skill gains a `pre_pass:` block in its frontmatter and replaces its file-discovery section body with a single reference to the shared fragment. No changes to `setup.sh` or the Octopus runtime — this is LLM instruction protocol only.

**Tech Stack:** Pure markdown. Grep-based bash tests (project convention).

**Spec:** `docs/specs/pre-llm-audit-pass.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `skills/_shared/audit-pre-pass.md` | create | 4-step pre-pass protocol shared by all audit skills |
| `tests/test_pre_llm_audit_pass.sh` | create | Structural grep tests verifying fragment and skill wiring |
| `skills/money-review/SKILL.md` | modify | Add `pre_pass:` frontmatter; replace `## File Discovery` body |
| `skills/security-scan/SKILL.md` | modify | Add `pre_pass:` frontmatter; replace `## File Discovery` body |
| `skills/cross-stack-contract/SKILL.md` | modify | Add `pre_pass:` frontmatter; replace `## Stack Discovery` body |
| `skills/tenant-scope-audit/SKILL.md` | modify | Add `pre_pass:` frontmatter; replace `## File Discovery` body |

---

## Task 1: Shared fragment + test scaffolding

**Files:**
- Create: `skills/_shared/audit-pre-pass.md`
- Create: `tests/test_pre_llm_audit_pass.sh`

- [ ] **Step 1: Write the failing tests**

```bash
#!/usr/bin/env bash
# tests/test_pre_llm_audit_pass.sh
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; ((PASS++))
  else
    echo "FAIL: $desc"; ((FAIL++))
  fi
}

# T1: shared fragment exists
check "shared fragment exists" \
  test -f "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"

# T2: fragment contains all 4 step markers
check "fragment contains Step 1" \
  grep -q "Step 1" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"
check "fragment contains Step 2" \
  grep -q "Step 2" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"
check "fragment contains Step 3" \
  grep -q "Step 3" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"
check "fragment contains Step 4" \
  grep -q "Step 4" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"

# T3: fragment contains key protocol terms
check "fragment contains 'early exit'" \
  grep -qi "early exit" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"
check "fragment contains 'CANDIDATE_FILES'" \
  grep -q "CANDIDATE_FILES" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"

# T4: each skill has pre_pass: in frontmatter
check "money-review has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/money-review/SKILL.md"
check "security-scan has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/security-scan/SKILL.md"
check "cross-stack-contract has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/cross-stack-contract/SKILL.md"
check "tenant-scope-audit has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/tenant-scope-audit/SKILL.md"

# T5: security-scan file_patterns contains \.env
check "security-scan file_patterns contains .env" \
  grep -A2 "file_patterns:" "$OCTOPUS_DIR/skills/security-scan/SKILL.md" | grep -q "env"

# T6: each skill references audit-pre-pass.md in its discovery section
check "money-review references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/money-review/SKILL.md"
check "security-scan references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/security-scan/SKILL.md"
check "cross-stack-contract references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/cross-stack-contract/SKILL.md"
check "tenant-scope-audit references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/tenant-scope-audit/SKILL.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test_pre_llm_audit_pass.sh`
Expected: FAIL on T1 (fragment not found) and all downstream checks

- [ ] **Step 3: Create `skills/_shared/audit-pre-pass.md`**

```markdown
# Pre-Pass Protocol

## Pre-Pass (deterministic file discovery)

Execute before LLM analysis. Steps run in order; abort the skill at Step 2 if no candidates are found.

**Step 1 — candidate files**

Run:
```
git diff --name-only <base>..<ref> | grep -E "<pre_pass.file_patterns from this skill's frontmatter>"
```
Store the result as `CANDIDATE_FILES` (newline-separated list of file paths).

**Step 2 — early exit**

If `CANDIDATE_FILES` is empty, print:
```
no <skill-domain> changes detected
```
and stop. Do not proceed to inspection checks.

**Step 3 — optional line filter**

If this skill's frontmatter defines `pre_pass.line_patterns`, apply a secondary filter.
For each file in `CANDIDATE_FILES`, check whether it contains at least one added or changed line matching the pattern:
```
git diff <base>..<ref> -- <file> | grep -E "^\+" | grep -qE "<pre_pass.line_patterns>"
```
Remove files that do not match. If all files are removed, apply the same early exit as Step 2.

**Step 4 — scoped diff output**

Produce the input for LLM analysis:
```
## Scoped files
<CANDIDATE_FILES — one path per line>

<git diff <base>..<ref> -- <CANDIDATE_FILES>>
```
Pass this output to the LLM in place of the full diff. Do not re-run `git diff` without the file filter.
```

- [ ] **Step 4: Run tests to verify T1–T3 pass**

Run: `bash tests/test_pre_llm_audit_pass.sh`
Expected: T1–T3 PASS (7 checks); T4–T6 still FAIL (skills not yet updated)

- [ ] **Step 5: Commit**

```bash
git add skills/_shared/audit-pre-pass.md tests/test_pre_llm_audit_pass.sh
git commit -m "feat(audit): add shared pre-pass protocol fragment and test scaffolding (RM-025)"
```

---

## Task 2: money-review + security-scan

**Files:**
- Modify: `skills/money-review/SKILL.md`
- Modify: `skills/security-scan/SKILL.md`

- [ ] **Step 1: Update `skills/money-review/SKILL.md` frontmatter**

Add `pre_pass:` block immediately after `triggers:` in the frontmatter:

```yaml
pre_pass:
  file_patterns: "billing|payment|charge|cobran|split|invoice|subscription|asaas|stripe|pix|webhook|refund|reembolso|tax|taxa|fee"
  line_patterns: "PERCENT[_A-Z]*\\s*=|\\bdecimal\\b|asaas|stripe|mercadopago|webhook.*(signature|hmac)"
```

Replace the body of `## File Discovery` with:

```markdown
## File Discovery

Follow the Pre-Pass protocol in `skills/_shared/audit-pre-pass.md`.
Use this skill's `pre_pass.file_patterns` and `pre_pass.line_patterns` from the frontmatter.
Proceed to inspection checks only with the scoped diff produced by Step 4.
```

- [ ] **Step 2: Update `skills/security-scan/SKILL.md` frontmatter**

Add `pre_pass:` block immediately after `triggers:` in the frontmatter:

```yaml
pre_pass:
  file_patterns: "auth|jwt|oauth|secret|token|password|credential|permission|role|middleware|\\.env"
  line_patterns: "password|secret|Bearer|Authorization|SQL|querySelector"
```

Replace the body of `## File Discovery` with:

```markdown
## File Discovery

Follow the Pre-Pass protocol in `skills/_shared/audit-pre-pass.md`.
Use this skill's `pre_pass.file_patterns` and `pre_pass.line_patterns` from the frontmatter.
Proceed to inspection checks only with the scoped diff produced by Step 4.
```

- [ ] **Step 3: Run tests**

Run: `bash tests/test_pre_llm_audit_pass.sh`
Expected: money-review and security-scan checks now PASS; cross-stack-contract and tenant-scope-audit still FAIL

- [ ] **Step 4: Commit**

```bash
git add skills/money-review/SKILL.md skills/security-scan/SKILL.md
git commit -m "feat(audit): wire pre-pass protocol into money-review and security-scan (RM-025)"
```

---

## Task 3: cross-stack-contract + tenant-scope-audit

**Files:**
- Modify: `skills/cross-stack-contract/SKILL.md`
- Modify: `skills/tenant-scope-audit/SKILL.md`

- [ ] **Step 1: Update `skills/cross-stack-contract/SKILL.md` frontmatter**

Add `pre_pass:` block immediately after `triggers:` in the frontmatter:

```yaml
pre_pass:
  file_patterns: "controller|endpoint|route|openapi|swagger|dto|request|response|contract"
  line_patterns: "\\[Route\\]|\\[HttpGet\\]|\\[HttpPost\\]|app\\.map|MapGet|MapPost|fetch\\(|axios\\."
```

Replace the body of `## Stack Discovery` with:

```markdown
## Stack Discovery

Follow the Pre-Pass protocol in `skills/_shared/audit-pre-pass.md`.
Use this skill's `pre_pass.file_patterns` and `pre_pass.line_patterns` from the frontmatter.
Proceed to inspection checks only with the scoped diff produced by Step 4.
```

- [ ] **Step 2: Update `skills/tenant-scope-audit/SKILL.md` frontmatter**

Add `pre_pass:` block immediately after `triggers:` in the frontmatter:

```yaml
pre_pass:
  file_patterns: "tenant|org|workspace|organization|scope"
  line_patterns: "tenantId|orgId|workspaceId|TenantId|OrgId"
```

Replace the body of `## File Discovery` with:

```markdown
## File Discovery

Follow the Pre-Pass protocol in `skills/_shared/audit-pre-pass.md`.
Use this skill's `pre_pass.file_patterns` and `pre_pass.line_patterns` from the frontmatter.
Proceed to inspection checks only with the scoped diff produced by Step 4.
```

- [ ] **Step 3: Run all tests**

Run: `bash tests/test_pre_llm_audit_pass.sh`
Expected: all checks PASS (0 failures)

- [ ] **Step 4: Commit**

```bash
git add skills/cross-stack-contract/SKILL.md skills/tenant-scope-audit/SKILL.md
git commit -m "feat(audit): wire pre-pass protocol into cross-stack-contract and tenant-scope-audit (RM-025)"
```
